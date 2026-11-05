#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <wchar.h>
#include <stdbool.h>

// Crime Boss Steam build 25106786. No shared constants or loot prices are changed.
static HMODULE selfModule;
static void logLine(const char* message) {
    wchar_t path[MAX_PATH];
    GetModuleFileNameW(selfModule, path, MAX_PATH);
    wchar_t* slash = wcsrchr(path, L'\\');
    if (!slash) return;
    wcscpy(slash + 1, L"BagCapacity10x.log");
    FILE* f = NULL;
    f = _wfopen(path, L"a");
    if (f) {
        SYSTEMTIME t; GetLocalTime(&t);
        fprintf(f, "%04d-%02d-%02d %02d:%02d:%02d %s\n", t.wYear, t.wMonth, t.wDay,
                t.wHour, t.wMinute, t.wSecond, message);
        fclose(f);
    }
}
typedef struct Patch {
    DWORD rva;
    unsigned char expected[8];
    size_t size;
    DWORD constantRva; // Zero for the integer multiplication replacement.
    unsigned char replacement[8];
 } Patch;
static Patch patches[] = {
    {0x20789c3, {0xf3,0x0f,0x10,0x05,0x15,0x62,0x2d,0x03},8,0x52de65c,{}},
    {0x2085581, {0xf3,0x0f,0x10,0x05,0x57,0x96,0x2c,0x03},8,0x52de65c,{}},
    {0x208be88, {0x8d,0x04,0x5b,0xc1,0xe0,0x02},6,0,{0x6b,0xc3,0x78,0x90,0x90,0x90}},
    {0x208bebf, {0xf3,0x0f,0x10,0x0d,0x19,0x2d,0x2c,0x03},8,0x52de65c,{}},
    {0x208becf, {0xf3,0x0f,0x58,0x15,0x19,0xe4,0x85,0x03},8,0x52de65c,{}},
};
static bool writeCode(unsigned char* address, const unsigned char* data, size_t size) {
    DWORD previous;
    if (!VirtualProtect(address, size, PAGE_EXECUTE_READWRITE, &previous)) return false;
    memcpy(address, data, size);
    FlushInstructionCache(GetCurrentProcess(), address, size);
    DWORD ignored;
    return VirtualProtect(address, size, previous, &ignored) != FALSE;
}
static bool apply() {
    static bool applied = false;
    if (applied) return true;
    unsigned char* base = (unsigned char*)GetModuleHandleW(NULL);
    IMAGE_DOS_HEADER* dos = (IMAGE_DOS_HEADER*)base;
    IMAGE_NT_HEADERS64* nt = (IMAGE_NT_HEADERS64*)(base + dos->e_lfanew);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE || nt->Signature != IMAGE_NT_SIGNATURE ||
        nt->FileHeader.TimeDateStamp != 0x6a999094 || nt->OptionalHeader.SizeOfImage != 0x7a39000) {
        logLine("REFUSED: unsupported executable build; no changes applied."); return false;
    }
    if (*(float*)(base + 0x52de65c) != 120.0f) {
        logLine("REFUSED: constant validation failed; no changes applied."); return false;
    }
    for (size_t index = 0; index < sizeof(patches)/sizeof(patches[0]); ++index) {
        Patch* p = &patches[index];
        if (memcmp(base + p->rva, p->expected, p->size) != 0) {
            logLine("REFUSED: instruction mismatch or conflicting mod; no changes applied."); return false;
        }
        if (p->constantRva) {
            memcpy(p->replacement, p->expected, p->size);
            // Replace adding -12 with subtracting +120; use an immutable .rdata constant.
            if (p->rva == 0x208becf) p->replacement[2] = 0x5c;
            int32_t displacement = (int32_t)(p->constantRva - (p->rva + p->size));
            memcpy(p->replacement + 4, &displacement, sizeof(displacement));
        }
    }
    size_t done = 0;
    for (size_t index = 0; index < sizeof(patches)/sizeof(patches[0]); ++index) {
        Patch* p = &patches[index];
        // Include a failed write in rollback: protection restoration can fail after memcpy.
        ++done;
        if (!writeCode(base + p->rva, p->replacement, p->size)) {
            bool rolledBack = true;
            for (size_t j = 0; j < done; ++j)
                rolledBack = writeCode(base + patches[j].rva, patches[j].expected, patches[j].size) && rolledBack;
            logLine(rolledBack ? "ERROR: write failed; changes rolled back." : "ERROR: rollback incomplete; close game before playing.");
            return false;
        }
    }
    applied = true;
    logLine("APPLIED: bag capacity 12 -> 120; 5 verified code sites. TEST BUILD 0.1.0.");
    return true;
}
__declspec(dllexport) int luaopen_BagCapacity10x(void* state) {
    (void)state;
    apply();
    return 0; // Lua C function: no stack results and no dependency on Lua DLL ABI symbols.
}
BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) { selfModule = instance; DisableThreadLibraryCalls(instance); }
    return TRUE;
}
