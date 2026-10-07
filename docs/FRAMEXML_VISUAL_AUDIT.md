# WoW Forever 1.60.1 visual audit

Source audited: `Gethe/wow-ui-source` commit
`15666a6e67938a1ab5caf041406464251db111ca` (`1.60.1 (70245)`).

## Search box and filter bar

- `Blizzard_SocialUIShared/SocialUISharedTemplates.xml` defines
  `SocialUISearchBoxTemplate`, inheriting `SearchBoxNineSliceTemplate` and
  `UserScaledFrameTemplate`, and composes it in `SocialUIFilterBarTemplate`.
- `SocialUISearchBoxMixin` is implemented in
  `Blizzard_SocialUIShared/SocialUISharedTemplates.lua` and delegates to the
  shared `SearchBoxTemplate_*` functions.
- The filter is `SocialUISearchFilterDropdownTemplate`, inheriting
  `WowStyle1FilterDropdownTemplate`; Friends wires its real menu in
  `Blizzard_FriendsFrame/Mainline/FriendsListTemplates.lua`.
- FEFS safely reuses the shared `SearchBoxNineSliceTemplate`. It does not
  inherit the Social UI templates because `Blizzard_SocialUIShared` is not a
  dependency of the mail addon, and it does not add a decorative filter with
  no action.

## Vertical tabs, selection, hover, and tooltips

- `Blizzard_SocialUI/Mainline/SocialUITemplates.xml` defines
  `SocialUITabTemplate`, inheriting `LargeSideTabButtonTemplate`.
- `Blizzard_SocialUI/Mainline/SocialUITemplates.lua` defines
  `SocialUITabMixin`; `Blizzard_SocialUI/Mainline/SocialUI.lua` creates the
  tab pool and supplies the Friends atlases and tooltip names.
- The reusable base is defined in
  `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml` and implemented by
  `SidePanelTabButtonMixin` in the matching Lua file. Its art is
  `common-sidetab`, `common-sidetab-mask`, `common-sidetab-selected`, and
  `common-sidetab-hover`. Its tooltip path uses `GetAppropriateTooltip()`.
- FEFS reuses `LargeSideTabButtonTemplate` directly. It does not reuse
  `SocialUITabTemplate`, whose mixin, counter, pool lifecycle, and load order
  belong to `Blizzard_SocialUI`.
- General uses `friends-icon-tab-friends` and
  `friends-icon-tab-friends-inactive`. Favorites uses the existing
  `friends-icon-favorites` and `friends-icon-favorites-dis` atlases. Guild
  uses the native `Interface/GuildFrame/GuildLogo-NoLogoSm` texture because
  this build exposes no semantically correct guild side-tab atlas; the native
  selected and hover tab art still provides its state.

## Collapse arrow

- Shared horizontal navigation art is used by
  `Blizzard_GamepadSharedUtility/Page/PageIndicators.xml`:
  `common-icon-backarrow` and `common-icon-forwardarrow`.
- The square button styling comes from the same current UI art used by
  `SocialUIBattleNetMenuButtonTemplate`:
  `common-button-tertiary-square-normal` and
  `common-button-tertiary-square-pressed`.
- FEFS composes a plain button from those public atlases, avoiding a private
  Social UI mixin while preserving the existing collapse state and callback.

## Rows

Friends uses feature-specific card/list templates and state owned by its data
providers. FEFS retains its recycled six-row implementation, class visuals,
actions, and lightweight highlight instead of importing that lifecycle.
