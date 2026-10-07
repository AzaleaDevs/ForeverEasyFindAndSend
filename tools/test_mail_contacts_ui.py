"""Static checks for the FEFS mail contacts visual integration and package."""

from __future__ import annotations

import argparse
import hashlib
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "ForeverEasyFindAndSend"
UI_PATH = ADDON / "UI" / "MailContacts.lua"


def test_visual_source() -> None:
    source = UI_PATH.read_text(encoding="utf-8")

    assert '"SearchBoxNineSliceTemplate"' in source
    assert 'searchBox:HookScript("OnTextChanged", ScheduleSearchRefresh)' in source
    assert source.count('key = "GENERAL"') == 1
    assert source.count('key = "GUILD"') == 1
    assert source.count('key = "FAVORITES"') == 1
    assert '"LargeSideTabButtonTemplate"' in source
    assert 'button:SetChecked(tabName == activeTab)' in source
    assert "button:SetText(tab.label)" not in source
    assert '"friends-icon-tab-friends"' in source
    assert '"friends-icon-favorites"' in source
    assert '"Interface/GuildFrame/GuildLogo-NoLogoSm"' in source
    assert '"common-icon-forwardarrow"' in source
    assert '"common-icon-backarrow"' in source
    assert "UpdateCollapseButton(true)" in source
    assert "UpdateCollapseButton(false)" in source
    assert "ns.L.SHOW_CONTACTS" in source and "ns.L.HIDE_CONTACTS" in source
    assert "OnUpdate" not in source
    print("mail contacts visual source checks passed")


def test_localizations() -> None:
    required = {
        "enUS.lua": ("Search player...", "General", "Guild", "Favorites", "Hide Contacts", "Show Contacts"),
        "esES.lua": ("Buscar jugador...", "General", "Hermandad", "Favoritos", "Ocultar Agenda", "Mostrar Agenda"),
        "frFR.lua": ("Rechercher un joueur...", "Général", "Guilde", "Favoris", "Masquer les contacts", "Afficher les contacts"),
        "deDE.lua": ("Spieler suchen...", "Allgemein", "Gilde", "Favoriten", "Kontakte ausblenden", "Kontakte anzeigen"),
    }
    for filename, values in required.items():
        source = (ADDON / "Localization" / filename).read_text(encoding="utf-8")
        for value in values:
            assert value in source, f"{value!r} missing from {filename}"
        for key in ("TAB_GENERAL", "TAB_GUILD", "TAB_FAVORITES", "HIDE_CONTACTS", "SHOW_CONTACTS"):
            assert key in source, f"{key} missing from {filename}"
    print("mail contacts localization checks passed")


def test_whisper_controls_preserved() -> None:
    suggestions_path = ADDON / "UI" / "WhisperSuggestions.lua"
    expected_suggestions_hash = "6254d3c8c00c82ec7ee4c54b2ee8ef32479f7911d594ce34fddeec0a570e7c6f"
    assert hashlib.sha256(suggestions_path.read_bytes()).hexdigest() == expected_suggestions_hash

    integration = (ADDON / "Integrations" / "Whisper.lua").read_text(encoding="utf-8")
    assert "SetAltArrowKeyMode(false)" in integration
    assert 'WrapScript(editBox, "OnArrowPressed"' in integration
    assert 'WrapScript(editBox, "OnTabPressed"' in integration
    assert 'WrapScript(editBox, "OnEnterPressed"' in integration
    assert 'WrapScript(editBox, "OnEscapePressed"' in integration
    print("whisper control preservation checks passed")


def test_package(zip_path: Path) -> None:
    forbidden_parts = {".git", ".github", "tools", "tests", "assets", "screenshots"}
    with zipfile.ZipFile(zip_path) as archive:
        names = archive.namelist()
        assert names and all(name.startswith("ForeverEasyFindAndSend/") for name in names)
        assert "ForeverEasyFindAndSend/ForeverEasyFindAndSend.toc" in names
        assert not any(name.lower().endswith(".zip") for name in names)
        for name in names:
            assert not (set(Path(name).parts) & forbidden_parts), f"forbidden package entry: {name}"
    print("mail contacts package checks passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--zip", type=Path)
    args = parser.parse_args()
    test_visual_source()
    test_localizations()
    test_whisper_controls_preserved()
    if args.zip:
        test_package(args.zip)
    print("mail contacts UI checks passed")
