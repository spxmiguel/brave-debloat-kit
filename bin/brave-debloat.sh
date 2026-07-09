#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  brave-debloat.sh [options]

Options:
  --profile-dir PATH       Brave profile root, e.g. ~/.config/BraveSoftware/Brave-Browser-Nightly
  --profile-name NAME      Profile directory inside the root. Default: Default
  --disable-web3           Also disable Brave Wallet/Web3 provider and remove local wallet cache.
  --install-policy         Install Brave enterprise policy using pkexec/sudo when needed.
  --no-launcher            Do not create local low-bloat launcher and .desktop overrides.
  --dry-run                Print targets and exit before changing files.
  -h, --help               Show this help.

What it disables by default:
  Brave Ads, Rewards, Wallet UI, Brave News/Today, Leo/AI Chat, Talk entrypoints,
  background mode, sync, suggestions/telemetry clutter, crash/background extras,
  and generated caches for ads/rewards/AI/wallet.

Web3 is not disabled by default because some users intentionally use wallet APIs.
Use --disable-web3 to turn off the native Web3 provider too.
USAGE
}

log() { printf '[brave-debloat] %s\n' "$*"; }
die() { printf '[brave-debloat] error: %s\n' "$*" >&2; exit 1; }

PROFILE_ROOT=""
PROFILE_NAME="Default"
DISABLE_WEB3=0
CREATE_LAUNCHER=1
INSTALL_POLICY=0
DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile-dir) PROFILE_ROOT="${2:-}"; shift 2 ;;
    --profile-name) PROFILE_NAME="${2:-}"; shift 2 ;;
    --disable-web3) DISABLE_WEB3=1; shift ;;
    --install-policy) INSTALL_POLICY=1; shift ;;
    --no-launcher) CREATE_LAUNCHER=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq is required"

if [ -z "$PROFILE_ROOT" ]; then
  for candidate in \
    "$HOME/.config/BraveSoftware/Brave-Browser-Nightly" \
    "$HOME/.config/BraveSoftware/Brave-Browser" \
    "$HOME/.config/BraveSoftware/Brave-Browser-Beta"; do
    if [ -f "$candidate/Local State" ]; then
      PROFILE_ROOT="$candidate"
      break
    fi
  done
fi

[ -n "$PROFILE_ROOT" ] || die "could not find Brave profile root; pass --profile-dir"
[ -f "$PROFILE_ROOT/Local State" ] || die "missing Local State in $PROFILE_ROOT"

PROFILE_DIR="$PROFILE_ROOT/$PROFILE_NAME"
PREFS="$PROFILE_DIR/Preferences"
STATE="$PROFILE_ROOT/Local State"

[ -f "$PREFS" ] || die "missing Preferences in $PROFILE_DIR"

log "profile root: $PROFILE_ROOT"
log "profile name: $PROFILE_NAME"
log "disable web3: $DISABLE_WEB3"
log "install policy: $INSTALL_POLICY"
log "launcher: $CREATE_LAUNCHER"

if [ "$DRY_RUN" -eq 1 ]; then
  log "dry run requested; no files changed"
  exit 0
fi

if pgrep -x brave >/dev/null 2>&1; then
  log "closing running Brave processes"
  pkill -TERM -x brave || true
  sleep 2
fi

BACKUP_ROOT="$PROFILE_ROOT/debloat-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_ROOT"
cp -a "$PREFS" "$BACKUP_ROOT/Preferences"
cp -a "$STATE" "$BACKUP_ROOT/Local State"
log "backup: $BACKUP_ROOT"

tmp="$(mktemp)"
jq --argjson disable_web3 "$DISABLE_WEB3" '
  .browser.background_mode = {"enabled": false} |
  .background_mode = {"enabled": false} |
  .alternate_error_pages.enabled = false |
  .dns_prefetching.enabled = false |
  .enable_do_not_track = true |
  .search.suggest_enabled = false |
  .search.suggest_enabled_by_policy = false |
  .signin.allowed = false |
  .sync.suppress_start = true |
  .sync.requested = false |
  .hardware_acceleration_mode.enabled = true |
  .performance_tuning.high_efficiency_mode.enabled = true |
  .performance_tuning.battery_saver_mode.state = 1 |
  .session.restore_on_startup = 5 |

  .brave.enable_media_router_on_restart = false |
  .brave.web_discovery_enabled = false |
  .brave.enable_search_suggestions_by_default = false |

  .brave.brave_ads.enabled = false |
  .brave.brave_ads.ads_per_hour = 0 |
  .brave.brave_ads.should_allow_ads_subdivision_targeting = false |

  .brave.rewards.enabled = false |
  .brave.rewards.show_brave_rewards_button = false |
  .brave.rewards.show_brave_rewards_button_in_location_bar = false |

  .brave.today.enabled = false |
  .brave.today.opted_in = false |
  .brave.today.should_show_toolbar_button = false |
  .brave.new_tab_page.show_brave_news = false |
  .brave.new_tab_page.show_rewards = false |
  .brave.new_tab_page.show_stats = false |
  .brave.new_tab_page.show_branded_background_image = false |
  .brave.new_tab_page.show_together = false |
  .ntp.hide_all_widgets = true |
  .ntp.show_brave_news = false |
  .ntp.show_rewards = false |
  .ntp.show_sponsored_images = false |
  .ntp.show_stats = false |

  .brave.wallet.show_wallet_icon_on_toolbar = false |
  .brave.wallet.default_wallet = 0 |
  .brave.wallet.web3_provider = "None" |
  .brave.wallet.ethereum_provider = "None" |
  .brave.wallet.solana_provider = "None" |
  .brave.wallet.cardano_provider = "None" |
  .brave.wallet.bitcoin_provider = "None" |
  .brave.wallet.nft_discovery_enabled = false |
  .brave.wallet.auto_discover_assets = false |
  .brave.wallet.show_wallet_test_networks = false |
  .brave.wallet.show_wallet_suggestions = false |

  .brave.talk.disabled = true |
  .brave.talk.enabled = false |
  .brave.talk.show_toolbar_button = false |

  .brave.ai_chat.enabled = false |
  .brave.ai_chat.show_toolbar_button = false |
  .brave.ai_chat.sidebar_enabled = false |
  .brave.ai_chat.show_context_menu = false |
  .brave.ai_chat.show_in_location_bar = false |
  .brave.ai_chat.show_omnibox_entrypoint = false |
  .brave.ai_chat.omnibox_entrypoint_enabled = false |
  .brave.ai_chat.omnibox_autocomplete_enabled = false |
  .brave.ai_chat.open_leo_from_brave_search = false |
  .omnibox.show_ai_mode_omnibox_button = false |
  .omnibox.ai_mode_omnibox_entry_point = false |
  .autocomplete.ai_mode_omnibox_entry_point = false |

  .profile.default_content_setting_values.notifications = 2 |
  .profile.default_content_setting_values.geolocation = 2 |
  .profile.default_content_setting_values.background_sync = 2 |
  .profile.managed_default_content_settings.notifications = 2 |
  .profile.managed_default_content_settings.background_sync = 2 |
  del(.profile.content_settings.exceptions.brave_open_ai_chat) |
  del(.profile.content_settings.exceptions.site_engagement."chrome://leo-ai/,*") |
  del(.sync.data_type_status_for_sync_to_signin.ai_chat_conversation) |
  del(.sync.data_type_status_for_sync_to_signin.ai_thread) |
  if $disable_web3 == 1 then
    .brave.wallet.keyrings = {} |
    .brave.wallet.allow_external_wallet = false |
    .brave.wallet.default_base_currency = "USD" |
    .brave.wallet.default_base_cryptocurrency = "" |
    .profile.default_content_setting_values.brave_ethereum = 2 |
    .profile.default_content_setting_values.brave_solana = 2 |
    .profile.default_content_setting_values.brave_cardano = 2 |
    .profile.default_content_setting_values.brave_wallet = 2
  else . end
' "$PREFS" > "$tmp"
mv "$tmp" "$PREFS"
chmod 600 "$PREFS"

tmp="$(mktemp)"
jq --argjson disable_web3 "$DISABLE_WEB3" '
  .browser.background_mode = {"enabled": false} |
  .background_mode = {"enabled": false} |
  .brave.brave_ads.enabled_last_profile = false |
  .brave.p3a.enabled = false |
  .brave.p3a.notice_acknowledged = true |
  .brave.enable_search_suggestions_by_default = false |
  .brave.ai_chat.p3a_last_premium_status = false |
  .brave.sidebar.target_user_for_sidebar_enabled_test = false |
  .sync.disabled = true |
  .signin.allowed = false |
  .hardware_acceleration_mode.enabled = true |
  .browser.enabled_labs_experiments = ([
    "ai-mode-omnibox-entry-point@2",
    "brave-ai-chat@2",
    "brave-ai-chat-agent-profile@2",
    "brave-ai-chat-context-menu-rewrite-in-place@2",
    "brave-ai-chat-conversation-share@2",
    "brave-ai-chat-detailed-page-content-extraction@2",
    "brave-ai-chat-global-side-panel@2",
    "brave-ai-chat-history@2",
    "brave-ai-chat-open-leo-from-brave-search@2",
    "brave-ai-chat-rich-search-widgets@2",
    "brave-ai-chat-show-input-on-new-tab-page@2",
    "brave-ai-chat-tab-management-tool@2",
    "brave-ai-chat-user-choice-tool@2",
    "brave-ai-chat-web-content-association-default@2",
    "brave-news-feed-update@2",
    "brave-news-peek@2",
    "brave-news-sidebar@2",
    "hide-aim-omnibox-entrypoint-on-user-input@1",
    "webui-omnibox-hide-aim-url@1"
  ] + (.browser.enabled_labs_experiments // []) | unique) |
  del(.p3a.logs_constellation_prep) |
  del(.p3a.logs_constellation_prep_express) |
  del(.p3a.logs_constellation_prep_slow) |
  del(.brave.ai_chat.p3a_entry_point_usages) |
  del(.brave.ai_chat.p3a_omnibox_autocomplete) |
  del(.brave.ai_chat.p3a_omnibox_open) |
  del(.brave.ai_chat.p3a_sidebar_usages) |
  if $disable_web3 == 1 then
    .browser.enabled_labs_experiments = ([
      "brave-wallet-bitcoin@2",
      "brave-wallet-cardano@2",
      "brave-wallet-polkadot@2",
      "brave-wallet-zcash@2",
      "brave-wallet-enable-ankr-balances@2",
      "brave-wallet-enable-transaction-simulations@2"
    ] + (.browser.enabled_labs_experiments // []) | unique)
  else . end
' "$STATE" > "$tmp"
mv "$tmp" "$STATE"
chmod 600 "$STATE"

log "removing generated bloat caches"
rm -rf \
  "$PROFILE_DIR/AIChat" \
  "$PROFILE_DIR/AIChat-journal" \
  "$PROFILE_DIR/ads_service" \
  "$PROFILE_DIR/BraveWallet" \
  "$PROFILE_DIR/Rewards.log" \
  "$PROFILE_DIR/RewardsCreators.db" \
  "$PROFILE_DIR/RewardsCreators.db-journal" \
  "$PROFILE_DIR/DawnWebGPUCache" \
  "$PROFILE_DIR/DawnGraphiteCache" \
  "$PROFILE_DIR/GPUCache" \
  "$PROFILE_ROOT/Crash Reports" \
  "$PROFILE_ROOT/GPUPersistentCache/GPUCache"

if [ "$DISABLE_WEB3" -eq 1 ]; then
  rm -rf "$PROFILE_DIR/Local Extension Settings/odbfpeeihdkbihmopkbjmoonfanlbfcl"
fi

if [ "$CREATE_LAUNCHER" -eq 1 ]; then
  BIN_DIR="$HOME/.local/bin"
  APP_DIR="$HOME/.local/share/applications"
  mkdir -p "$BIN_DIR" "$APP_DIR"

  BRAVE_BIN=""
  for candidate in brave-browser-nightly brave-browser-beta brave-browser; do
    if command -v "$candidate" >/dev/null 2>&1; then
      BRAVE_BIN="$(command -v "$candidate")"
      break
    fi
  done
  [ -n "$BRAVE_BIN" ] || die "could not find Brave executable for launcher"

  LAUNCHER="$BIN_DIR/brave-debloated"
  WEB3_DISABLE_FEATURES=""
  if [ "$DISABLE_WEB3" -eq 1 ]; then
    WEB3_DISABLE_FEATURES=",BraveWallet,BraveWalletBitcoin,BraveWalletBitcoinImport,BraveWalletBitcoinLedger,BraveWalletCardano,BraveWalletPolkadot,BraveWalletZCash,BraveWalletAnkrBalances,BraveWalletTransactionSimulations"
  fi
  cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
exec "$BRAVE_BIN" \\
  --disable-background-mode \\
  --disable-background-networking \\
  --disable-sync \\
  --disable-default-apps \\
  --disable-brave-extension \\
  --disable-breakpad \\
  --disable-crash-reporter \\
  --disable-component-extensions-with-background-pages \\
  --disable-domain-reliability \\
  --disable-features=MediaRouter,OptimizationHints,TabHoverCardImages,Translate,InterestFeedContentSuggestions,SidePanelPinning,AutofillServerCommunication,BraveNewsFeedUpdate,BraveNewsPeek,BraveNewsSidebar,AiModeOmniboxEntryPoint,AIChatOmniboxEntrypoint,AIChatOmniboxAutocomplete,AIChatOmniboxOpen,BraveAIChatOmniboxEntrypoint,BraveAIChatOmniboxAutocomplete,BraveAIChatOmniboxOpen,BraveAIChat,BraveAIChatEnabled,AIChatService,AIChatPanel,AIChatButton,AIChatHistory,AIChatFirst,AIChatAgentProfile,AIChatContextMenuRewriteInPlace,AIChatConversationShare,AIChatDetailedPageContentExtraction,AIChatGlobalSidePanelEverywhere,AIChatUserChoiceTool,OpenAIChatFromBraveSearch,ShowAIChatInputOnNewTabPage,BraveAIChatAgentProfile,BraveAIChatAllowPrivateIps,BraveAIChatContextMenuRewriteInPlace,BraveAIChatConversationShare,BraveAIChatDetailedPageContentExtraction,BraveAIChatGlobalSidePanel,BraveAIChatHistory,BraveAIChatOpenLeoFromBraveSearch,BraveAIChatRichSearchWidgets,BraveAIChatShowInputOnNewTabPage,BraveAIChatTabManagementTool,BraveAIChatUserChoiceTool,BraveAIChatWebContentAssociationDefault,BraveAIFirst,BraveAIHostSpecificDistillation,BraveRewardsAnimatedBackground,BraveRewardsPlatformCreatorDetection$WEB3_DISABLE_FEATURES \\
  --enable-features=HideAimOmniboxEntrypointOnUserInput,WebUIOmniboxHideAimUrl \\
  --enable-low-end-device-mode \\
  --force-device-scale-factor=0.9 \\
  --process-per-site \\
  --renderer-process-limit=4 \\
  "\$@"
EOF
  chmod +x "$LAUNCHER"

  for desktop_id in brave-browser-nightly com.brave.Browser.nightly brave-browser com.brave.Browser; do
    cat > "$APP_DIR/$desktop_id.desktop" <<EOF
[Desktop Entry]
Version=1.0
Name=Brave Web Browser
GenericName=Web Browser
Comment=Debloated Brave launcher
Exec=$LAUNCHER %U
StartupNotify=true
Terminal=false
Icon=brave-browser
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Exec=$LAUNCHER

[Desktop Action new-private-window]
Name=New Incognito Window
Exec=$LAUNCHER --incognito
EOF
  done

  update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
  log "launcher: $LAUNCHER"
fi

if [ "$INSTALL_POLICY" -eq 1 ]; then
  POLICY_TMP="$(mktemp)"
  cat > "$POLICY_TMP" <<'EOF'
{
  "BraveWalletDisabled": true,
  "BraveRewardsDisabled": true,
  "BraveTalkDisabled": true,
  "BraveNewsDisabled": true,
  "BraveAIChatEnabled": false,
  "BraveP3AEnabled": false,
  "BraveStatsPingEnabled": 0,
  "BraveWebDiscoveryEnabled": 0,
  "BraveVPNDisabled": true,
  "BravePlaylistEnabled": 0,
  "BraveSpeedreaderEnabled": 0,
  "BraveWaybackMachineEnabled": 0,
  "BackgroundModeEnabled": false,
  "BrowserSignin": 0,
  "SyncDisabled": true,
  "DefaultNotificationsSetting": 2,
  "DefaultGeolocationSetting": 2,
  "NewTabPageLocation": "about:blank",
  "HomepageLocation": "about:blank",
  "HomepageIsNewTabPage": false,
  "RestoreOnStartup": 5
}
EOF
  if [ "$(id -u)" -eq 0 ]; then
    mkdir -p /etc/brave/policies/managed
    install -m 0644 -o root -g root "$POLICY_TMP" /etc/brave/policies/managed/brave-debloat.json
  elif command -v pkexec >/dev/null 2>&1; then
    pkexec /bin/sh -c "mkdir -p /etc/brave/policies/managed && install -m 0644 -o root -g root '$POLICY_TMP' /etc/brave/policies/managed/brave-debloat.json"
  elif command -v sudo >/dev/null 2>&1; then
    sudo /bin/sh -c "mkdir -p /etc/brave/policies/managed && install -m 0644 -o root -g root '$POLICY_TMP' /etc/brave/policies/managed/brave-debloat.json"
  else
    die "policy install requires root, pkexec, or sudo"
  fi
  rm -f "$POLICY_TMP"
  log "policy: /etc/brave/policies/managed/brave-debloat.json"
fi

log "done"
log "restart Brave to apply every change"
