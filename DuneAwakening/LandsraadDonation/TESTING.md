# Landsraad Donation regression checks

From this directory, install the developer dependencies and run the checks with Python 3.11 or newer.

    python -m pip install -r tests/requirements-dev.txt
    python tests/check_update.py

To check your installation after a Steam or WPS update, pass the shipping executable and launcher directory.

    python tests/check_update.py --game-exe "G:/steam/steamapps/common/DuneAwakening/DuneSandbox/Binaries/Win64/DuneSandbox-Win64-Shipping.exe" --wps-root "G:/WPS_launcher_dune_awakanin"

The suite checks the package, translations and simulated donation, inventory, reward and progress flows. It compares selected installed files against a recorded local runtime fingerprint. A changed fingerprint returns a failure and calls for focused in-game testing before updating the baseline. This suite starts no game and touches no save. It cannot establish that a new Unreal build still safely runs the native payment and reward calls.
