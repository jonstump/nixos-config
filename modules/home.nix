{ config, pkgs, lib, ... }:

{
  # ── Home Manager state version ────────────────────────────────────────────
  # Like system.stateVersion — do not change after first activation.
  home.stateVersion = "24.11";

  # ── Basic identity ────────────────────────────────────────────────────────
  home.username = "jon"; # Must match users.users.<name> in core.nix
  home.homeDirectory = "/home/jon";

  # Allow home-manager to manage itself
  programs.home-manager.enable = true;

  # ── XDG directories ───────────────────────────────────────────────────────
  xdg.enable = true;
  xdg.userDirs = {
    enable       = true;
    createDirectories = true;
    desktop      = "${config.home.homeDirectory}/Desktop";
    documents    = "${config.home.homeDirectory}/Documents";
    download     = "${config.home.homeDirectory}/Downloads";
    music        = "${config.home.homeDirectory}/Music";
    pictures     = "${config.home.homeDirectory}/Pictures";
    videos       = "${config.home.homeDirectory}/Videos";
  };

  # ============================================================
  # ── Neovim / LazyVim ────────────────────────────────────────
  # ============================================================
  # We install Neovim via the system package in core.nix.
  # LazyVim is a Neovim config distribution (not a plugin itself) —
  # it's a curated starter config that bootstraps lazy.nvim and a
  # sensible set of plugins on first launch.
  #
  # Strategy:
  #   1. Drop the LazyVim bootstrap init.lua into ~/.config/nvim/
  #   2. Install the external CLI tools LazyVim plugins rely on
  #      (formatters, LSP servers, linters) via Home Manager packages
  #      so they are always on PATH and managed by Nix.
  #   3. On first `nvim` launch, lazy.nvim downloads and compiles the
  #      plugins into ~/.local/share/nvim/lazy/ (not managed by Nix —
  #      this is intentional; LazyVim handles plugin updates itself).
  #
  # To update plugins after install: open nvim and run :Lazy update

  xdg.configFile."nvim/init.lua" = {
    # This is the canonical LazyVim bootstrap snippet. It installs
    # lazy.nvim if not present, then hands off to LazyVim's defaults.
    # Add your own plugins / overrides in lua/plugins/ (see note below).
    text = ''
      -- Bootstrap lazy.nvim
      local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
      if not (vim.uv or vim.loop).fs_stat(lazypath) then
        local lazyrepo = "https://github.com/folke/lazy.nvim.git"
        local out = vim.fn.system({
          "git", "clone",
          "--filter=blob:none",
          "--branch=stable",
          lazyrepo,
          lazypath,
        })
        if vim.v.shell_error ~= 0 then
          vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out,                            "WarningMsg" },
            { "\nPress any key to exit...",   "" },
          }, true, {})
          vim.fn.getchar()
          os.exit(1)
        end
      end
      vim.opt.rtp:prepend(lazypath)

      -- LazyVim setup — pass an empty opts table to use all defaults.
      -- Override options in lua/config/options.lua (created below).
      require("lazy").setup({
        spec = {
          -- Import LazyVim and its default plugin specs
          { "LazyVim/LazyVim", import = "lazyvim.plugins" },
          -- Your own plugin overrides go in lua/plugins/
          { import = "plugins" },
        },
        defaults = {
          lazy    = false,
          version = false, -- Always use latest git commits
        },
        install  = { colorscheme = { "tokyonight", "habamax" } },
        checker  = { enabled = true }, -- Auto-check for plugin updates
        performance = {
          rtp = {
            -- Disable built-in plugins we don't need
            disabled_plugins = {
              "gzip", "tarPlugin", "tohtml",
              "tutor", "zipPlugin",
            },
          },
        },
      })
    '';
  };

  # Personal options / keymaps — LazyVim looks for these at startup.
  # Edit these files directly to customise your Neovim experience.
  xdg.configFile."nvim/lua/config/options.lua" = {
    text = ''
      -- Options applied on top of LazyVim defaults
      vim.opt.relativenumber = true   -- Relative line numbers
      vim.opt.scrolloff      = 8      -- Keep 8 lines visible above/below cursor
      vim.opt.sidescrolloff  = 8
      vim.opt.wrap           = false  -- No line wrapping
      vim.opt.tabstop        = 2
      vim.opt.shiftwidth     = 2
      vim.opt.expandtab      = true
      vim.g.mapleader        = " "    -- Space as leader key (LazyVim default)
    '';
  };

  xdg.configFile."nvim/lua/config/keymaps.lua" = {
    # Custom keymaps on top of LazyVim's defaults.
    # Add your own bindings here rather than modifying LazyVim internals.
    text = ''
      -- Example: save with Ctrl-S in normal and insert mode
      vim.keymap.set({ "n", "i" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })
      -- Example: clear search highlight with Escape
      vim.keymap.set("n", "<Esc>", "<cmd>noh<cr>", { desc = "Clear search highlight" })
    '';
  };

  # Stub plugins directory — lazy.nvim will error if the import target is absent
  xdg.configFile."nvim/lua/plugins/.keep".text = ''
    -- Drop your plugin specs here as lua files, e.g. lua/plugins/colorscheme.lua
    -- LazyVim will auto-import everything in this directory.
    -- See https://www.lazyvim.org/configuration/plugins
  '';

  # ── External tools expected by LazyVim plugins ────────────────────────────
  # LazyVim's default plugin set shells out to these binaries. Installing
  # them via Nix means they're always present and version-locked with the
  # rest of the system rather than relying on Mason (LazyVim's in-editor
  # package manager) which is harder to reproduce.
  home.packages = with pkgs; [
    # ── Treesitter compiler (required by nvim-treesitter) ────────────────
    gcc     # Treesitter builds parsers from C source at runtime

    # ── LSP servers ──────────────────────────────────────────────────────
    lua-language-server         # Lua (used by LazyVim config itself)
    nil                         # Nix LSP
    nixd                        # Alternative Nix LSP with better completion
    bash-language-server        # Shell scripts
    nodePackages.typescript-language-server  # TS / JS
    nodePackages.vscode-langservers-extracted # HTML, CSS, JSON, ESLint
    pyright                     # Python (static type checker + LSP)
    rust-analyzer               # Rust

    # ── Formatters (used by conform.nvim, LazyVim's default formatter) ───
    stylua                      # Lua formatter
    nixfmt-rfc-style            # Nix formatter (RFC-style)
    nodePackages.prettier       # JS/TS/HTML/CSS/Markdown
    black                       # Python formatter
    isort                       # Python import sorter
    shfmt                       # Shell formatter
    rustfmt                     # Rust formatter (also provided by rust-analyzer)

    # ── Linters (used by nvim-lint) ───────────────────────────────────────
    shellcheck                  # Shell script linter
    nodePackages.eslint_d       # Fast JS/TS linter daemon

    # ── Fuzzy finder dependencies (telescope.nvim / fzf-lua) ────────────
    # fzf and ripgrep are also in the system packages (core.nix), but
    # including them here makes the home environment self-contained.
    fzf
    ripgrep
    fd

    # ── Clipboard integration (required for system clipboard in Wayland) ─
    wl-clipboard   # wl-copy / wl-paste — Wayland clipboard CLI tools

    # ── Git tooling (used by LazyVim's git plugins) ───────────────────────
    git
    lazygit        # TUI git client — opened inside nvim with <leader>gg
    delta          # Better git diff pager

    # ── Misc utilities LazyVim plugins call out to ────────────────────────
    gnumake        # Some Treesitter parsers need make
    unzip          # Mason fallback extracter (less needed when using Nix)
  ];

  # ── Git ───────────────────────────────────────────────────────────────────
  programs.git = {
    enable      = true;
    # Fill in your details:
    userName    = "Jon Stump";
    userEmail   = "jmstump@gmail.com";
    extraConfig = {
      core.editor   = "nvim";
      pull.rebase   = true;
      init.defaultBranch = "main";
      delta = {
        # Use delta as the default diff pager for a much nicer git diff output
        navigate    = true;
        line-numbers = true;
        side-by-side = true;
      };
    };
    delta.enable = true;  # Wire delta in as the pager
  };

  # ── Kitty terminal ────────────────────────────────────────────────────────
  # Kitty is installed as a system package in desktop.nix. Its config lives
  # here so Home Manager keeps it in sync declaratively.
  programs.kitty = {
    enable   = true;
    font = {
      name = "Mononoki Nerd Font";
      size = 13;
    };
    settings = {
      # Appearance
      background_opacity      = "0.95";
      window_padding_width    = 8;
      hide_window_decorations = "no";
      tab_bar_style           = "powerline";
      tab_powerline_style     = "slanted";

      # Behaviour
      scrollback_lines        = 10000;
      enable_audio_bell       = false;
      copy_on_select          = "clipboard";
      strip_trailing_spaces   = "smart";

      # Performance — good defaults for a fast GPU
      sync_to_monitor         = true;
      repaint_delay           = 10;
      input_delay             = 3;
    };
    # Keyboard shortcuts
    keybindings = {
      "ctrl+shift+enter"  = "new_window_with_cwd";
      "ctrl+shift+t"      = "new_tab_with_cwd";
      "ctrl+shift+."      = "move_tab_forward";
      "ctrl+shift+,"      = "move_tab_backward";
    };
  };

  # ── Bash shell ────────────────────────────────────────────────────────────
  programs.bash = {
    enable = true;
    historySize       = 50000;
    historyFileSize   = 100000;
    historyControl    = [ "ignoredups" "ignorespace" "erasedups" ];

    shellAliases = {
      # Nix shortcuts
      rebuild   = "sudo nixos-rebuild switch --flake /etc/nixos/nixos-config#gaming-pc";
      rebuild-b = "sudo nixos-rebuild boot   --flake /etc/nixos/nixos-config#gaming-pc";
      nix-gc    = "sudo nix-collect-garbage -d && nix-collect-garbage -d";
      flake-up  = "cd /etc/nixos/nixos-config && nix flake update";

      # Navigation
      ls  = "eza --icons --group-directories-first";
      ll  = "eza -lah --icons --group-directories-first --git";
      lt  = "eza --tree --icons --level=2";
      cat = "bat --style=auto";

      # Git
      g   = "git";
      gs  = "git status";
      gd  = "git diff";
      gp  = "git push";
      gl  = "git pull";
      lg  = "lazygit";

      # Neovim
      v   = "nvim";
      vi  = "nvim";
      vim = "nvim";
    };

    initExtra = ''
      # fzf keybindings and completion
      eval "$(fzf --bash)"

      # Fastfetch on new terminal (remove if you find it annoying)
      if [[ $- == *i* ]] && command -v fastfetch &>/dev/null; then
        fastfetch
      fi
    '';
  };

  # ── Syncthing (user service) ──────────────────────────────────────────────
  # Syncthing is installed as a system package in desktop.nix. Running it as
  # a user systemd service means it starts on login and runs under your UID,
  # which is the standard setup for a single-user desktop machine.
  services.syncthing = {
    enable = true;
    # Syncthing's web UI is available at http://localhost:8384 by default.
    # Add your device IDs and shared folders via the web UI or by editing
    # ~/.config/syncthing/config.xml after the first run.
  };

  # ============================================================
  # ── KDE Plasma configuration (plasma-manager) ───────────────
  # ============================================================
  # plasma-manager writes KDE config files declaratively via Home Manager.
  # Changes here take effect on the next login (or `home-manager switch`).
  #
  # IMPORTANT: plasma-manager cannot reconfigure a running Plasma session.
  # Log out and back in after any changes to this section.

  programs.plasma = {
    enable = true;

    # ── Workspace appearance ──────────────────────────────────────────────
    workspace = {
      # Colour scheme — "BreezeDark" is the default dark theme for KDE Plasma.
      # Other built-in options: "Breeze", "BreezeLight", "BreezeHighContrast"
      colorScheme    = "BreezeDark";

      # Icon theme — "breeze-dark" matches the dark colour scheme.
      # Other options: "breeze", "hicolor", "Adwaita"
      iconTheme      = "breeze-dark";

      # Window decoration theme
      theme          = "breeze-dark";

      # Cursor — "breeze_cursors" is the default KDE cursor theme
      cursorTheme    = "breeze_cursors";
      cursorSize     = 24;

      # Wallpaper — points to a file path. Change to your preferred image.
      # Leave as null to keep whatever wallpaper is set interactively.
      # wallpaper = "${pkgs.kdePackages.plasma-workspace}/share/wallpapers/Next/contents/images/3440x1440.png";
    };

    # ── Panels ────────────────────────────────────────────────────────────
    # This replaces the default bottom panel with a top panel containing
    # the same standard widgets in a layout typical for macOS-style desktops.
    panels = [
      {
        # ── Top bar ───────────────────────────────────────────────────────
        location = "top";   # Move the taskbar to the top of the screen
        height   = 44;
        floating = false;   # Set to true for the "floating pill" look

        widgets = [
          # Application launcher (start menu) — left side
          {
            name = "org.kde.plasma.kickoff";
            config.General = {
              icon              = "nix-snowflake-white"; # NixOS icon; falls back to default if not found
              showButtonIcon    = true;
              alphaSort         = true;    # Sort apps alphabetically
              showRecentFiles   = false;   # Keep the launcher clean
              showRecentApps    = false;
            };
          }

          # Window title / active task label — useful on a single large ultrawide
          {
            name = "org.kde.plasma.windowtitle";
            config.General = {
              showIcon  = true;
              textType  = 0; # 0 = application name, 1 = window title
            };
          }

          # Spacer — pushes everything after it to the right
          "org.kde.plasma.panelspacer"

          # Task manager — centred (between the two spacers)
          {
            name = "org.kde.plasma.icontasks";
            config.General = {
              showOnlyCurrentDesktop  = false;
              showOnlyCurrentActivity = true;
              launchers               = [
                # Pin your most-used apps here as launcher:// URIs.
                # The format is "applications:<desktop-file-name>.desktop"
                "applications:org.kde.konsole.desktop"
                "applications:org.kde.dolphin.desktop"
                "applications:firefox.desktop"
                "applications:brave-browser.desktop"
                "applications:steam.desktop"
                "applications:discord.desktop"
              ];
            };
          }

          # Second spacer — mirrors the first to keep tasks centred
          "org.kde.plasma.panelspacer"

          # System tray — right side
          {
            name = "org.kde.plasma.systemtray";
            config.General = {
              # Items shown directly in the panel (not hidden in the overflow)
              shownItems = [
                "org.kde.plasma.volume"          # Audio volume
                "org.kde.plasma.networkmanagement" # Network / WiFi
                "org.kde.plasma.bluetooth"        # Bluetooth
              ];
            };
          }

          # Digital clock — far right
          {
            name = "org.kde.plasma.digitalclock";
            config.Appearance = {
              showDate             = true;
              dateFormat           = "shortDate";
              showSeconds          = "Never";
              use24hFormat         = 2; # 0 = 12h, 1 = system, 2 = 24h
            };
          }
        ];
      }
    ];

    # ── KDE Shortcuts ─────────────────────────────────────────────────────
    shortcuts = {
      # Launch Kitty with Meta+Enter (Super/Windows key + Enter)
      "services/org.kde.konsole.desktop"."_launch"     = [];  # Remove default Konsole binding
      "org.kde.krunner.desktop"."_launch"              = [ "Alt+Space" "Alt+F2" "Search" ];

      kwin = {
        # Virtual desktop navigation
        "Switch to Desktop 1"  = "Meta+1";
        "Switch to Desktop 2"  = "Meta+2";
        "Switch to Desktop 3"  = "Meta+3";
        "Switch to Desktop 4"  = "Meta+4";

        # Move window to desktop
        "Window to Desktop 1"  = "Meta+Shift+1";
        "Window to Desktop 2"  = "Meta+Shift+2";
        "Window to Desktop 3"  = "Meta+Shift+3";
        "Window to Desktop 4"  = "Meta+Shift+4";

        # Window snapping
        "Window Quick Tile Left"   = "Meta+Left";
        "Window Quick Tile Right"  = "Meta+Right";
        "Window Quick Tile Top"    = "Meta+Up";
        "Window Quick Tile Bottom" = "Meta+Down";

        # Maximise / restore
        "Window Maximize"          = "Meta+Shift+Up";
        "Window Minimize"          = "Meta+H";

        # Close window
        "Window Close"             = "Alt+F4";
      };
    };

    # ── KRunner ───────────────────────────────────────────────────────────
    krunner = {
      # Activate KRunner with Alt+Space (also bound in shortcuts above)
      activateWhenTypingOnDesktop = false;
    };

    # ── Screen locker ─────────────────────────────────────────────────────
    kscreenlocker = {
      autoLock        = true;
      lockOnResume    = true;
      timeout         = 30;   # Lock after 10 minutes of inactivity
    };

    # ── Input devices ─────────────────────────────────────────────────────
    input = {
      mice = [
        {
          # Sane mouse defaults for gaming — no acceleration, consistent tracking
          enable              = true;
          acceleration        = -0.5; # Slight negative to approach 1:1 tracking
          accelerationProfile = 1;    # 1 = flat (no acceleration curve)
          naturalScroll       = false;
          leftHanded          = false;
        }
      ];
    };

    # ── Plasma Konsole profile ────────────────────────────────────────────
    # Sets the default Konsole profile to use Mononoki Nerd Font so it
    # matches the Kitty config and renders powerline/nerdfonts correctly.
    configFile = {
      # Tell Konsole to use the profile we declare below as default
      "konsolerc"."Desktop Entry".DefaultProfile = "NixOS.profile";

      # Konsole profile — lives in ~/.local/share/konsole/
      # plasma-manager writes this via configFile since there's no
      # dedicated Konsole profile module yet.
      "konsole/NixOS.profile" = {
        "Appearance"."Font"           = "Mononoki Nerd Font,13,-1,5,50,0,0,0,0,0";
        "Appearance"."ColorScheme"    = "Breeze";
        "General"."Name"              = "NixOS";
        "General"."Parent"            = "FALLBACK/";
        "Scrolling"."ScrollBarPosition" = 2; # 2 = hidden
        "Terminal Features"."BlinkingCursorEnabled" = true;
      };
    };
  };
}
