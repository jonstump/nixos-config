{ config, pkgs, lib, ... }:

{
  # ── Browsers ───────────────────────────────────────────────────────────────
  # Firefox is configured via the programs.firefox NixOS module, which lets
  # us declaratively install extensions and set policies without touching
  # user profiles by hand. Brave is installed as a plain package since it
  # does not have a comparable NixOS module.

  programs.firefox = {
    enable = true;

    # ── Policies (apply to all profiles, set via distribution policy JSON) ──
    # These are enforced at the browser level — they survive profile resets
    # and can't be overridden by the user without editing this file.
    policies = {
      # Disable the first-run welcome page and telemetry prompts
      DisableAppUpdate           = false; # Let Nix manage updates instead
      DisableTelemetry           = true;
      DisableFirefoxStudies      = true;
      DisablePocket              = true;   # Remove Pocket integration
      DisableFormHistory         = false;
      DisplayBookmarksToolbar    = "newtab";
      DontCheckDefaultBrowser    = true;
      NoDefaultBookmarks         = true;

      # Send "Do Not Track" header
      EnableTrackingProtection = {
        Value            = true;
        Locked           = false;
        Cryptomining     = true;
        Fingerprinting   = true;
      };

      # DNS over HTTPS via Cloudflare (change to your preferred resolver)
      DNSOverHTTPS = {
        Enabled          = true;
        ProviderURL      = "https://cloudflare-dns.com/dns-query";
        Locked           = false;
      };

      # ── Extensions ────────────────────────────────────────────────────────
      # Extensions listed here are installed automatically for every user.
      # IDs come from each add-on's AMO (addons.mozilla.org) listing.
      ExtensionSettings = {

        # uBlock Origin — the gold-standard content / ad blocker.
        # Manifest V2 version; stays in Firefox even after Chrome's MV2 removal.
        "uBlock0@raymondhill.net" = {
          install_url         = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode   = "force_installed"; # Can't be disabled by user
          default_area        = "navbar";
        };

        # Firefox Multi-Account Containers — isolate sites into colour-coded
        # containers so they can't track you across domains via cookies.
        "@testpilot-containers" = {
          install_url         = "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi";
          installation_mode   = "force_installed";
          default_area        = "navbar";
        };

        # Facebook Container — quarantines Facebook into its own container
        # automatically. Pairs well with Multi-Account Containers.
        "@contain-facebook" = {
          install_url         = "https://addons.mozilla.org/firefox/downloads/latest/facebook-container/latest.xpi";
          installation_mode   = "normal_installed"; # User can disable if desired
          default_area        = "navbar";
        };

        # 1Password — browser extension for the 1Password password manager.
        # Communicates with the 1Password desktop app (_1password-gui in desktop.nix)
        # via native messaging. The desktop app must be running and unlocked for
        # autofill to work — the extension is the primary way to interact with
        # 1Password in the browser, not a companion to a separate manager.
        "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
          install_url         = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
          installation_mode   = "normal_installed";
          default_area        = "navbar";
        };

        # KDE Plasma Integration — adds media/tab controls to the KDE taskbar
        # and enables browser-to-desktop notifications. Requires the
        # kdePackages.plasma-browser-integration package (in desktop.nix).
        "plasma-browser-integration@kde.org" = {
          install_url         = "https://addons.mozilla.org/firefox/downloads/latest/plasma-integration/latest.xpi";
          installation_mode   = "force_installed";
          default_area        = "navbar";
        };

        # Sponsorblock — community-sourced skip list for YouTube sponsorship
        # segments, intros, outros, and filler content.
        "sponsorBlocker@ajay.app" = {
          install_url         = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
          installation_mode   = "normal_installed";
          default_area        = "navbar";
        };

      }; # end ExtensionSettings

      # ── Sane defaults via policy ───────────────────────────────────────────
      # These mirror what power users set manually in about:config.
      Preferences = {
        # Privacy
        "privacy.trackingprotection.enabled"                    = { Value = true;  Status = "default"; };
        "privacy.trackingprotection.socialtracking.enabled"     = { Value = true;  Status = "default"; };
        "privacy.fingerprintingProtection"                      = { Value = true;  Status = "default"; };
        "privacy.resistFingerprinting"                          = { Value = false; Status = "default"; }; # Breaks some sites; enable manually if desired
        "privacy.globalprivacycontrol.enabled"                  = { Value = true;  Status = "default"; };

        # Performance — tune for a fast machine with 32 GB RAM
        "browser.cache.disk.capacity"                           = { Value = 1048576; Status = "default"; }; # 1 GB disk cache
        "gfx.webrender.all"                                     = { Value = true;  Status = "default"; }; # Force WebRender (GPU compositing)
        "layers.acceleration.force-enabled"                     = { Value = true;  Status = "default"; };
        "media.hardware-video-decoding.enabled"                 = { Value = true;  Status = "default"; }; # VA-API hardware decode

        # UI behaviour
        "browser.tabs.insertAfterCurrent"                       = { Value = true;  Status = "default"; }; # New tabs open next to current
        "browser.urlbar.trimURLs"                               = { Value = false; Status = "default"; }; # Show full URL
        "browser.compactmode.show"                              = { Value = true;  Status = "default"; }; # Expose compact density option
        "toolkit.legacyUserProfileCustomizations.stylesheets"   = { Value = true;  Status = "default"; }; # Allow userChrome.css
      };

    }; # end policies
  }; # end programs.firefox

  # ── Brave ─────────────────────────────────────────────────────────────────
  # Brave is a Chromium-based browser with a built-in ad blocker, fingerprint
  # randomisation, and optional crypto wallet. It's a good secondary browser
  # for sites that behave oddly in Firefox, and for testing Chromium compat.
  # Brave does not have a NixOS module with declarative extension management,
  # so extensions must be installed manually via the Chrome Web Store the
  # first time. The extensions below are noted as recommendations.
  #
  # Recommended Brave extensions (install manually after first launch):
  #   • uBlock Origin       — https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm
  #   • KDE Plasma Integration — https://chromewebstore.google.com/detail/plasma-integration/cimiefiiaegbelhefglklhhbackokmgm
  #   • SponsorBlock        — https://chromewebstore.google.com/detail/sponsorblock-for-youtube/mnjggcdmjocbbbhaepdhchncahnbgone
  #   • 1Password           — https://chromewebstore.google.com/detail/1password-password-manager/aeblfdkhhhdcdjpifhhbdiojplfjncoa
  environment.systemPackages = with pkgs; [
    brave
  ];

}
