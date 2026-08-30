Name:       harbour-meridon

Summary:    Native Mastodon client with Lists support
Version:    1.1
Release:    1
License:    GPLv3
URL:        http://example.org/
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   qt5-qtimageformats-plugin-webp
# TODO: verify and pin the exact package names providing the
# Amber.Web.Authorization (OAuth2) and Sailfish.WebView QML plugins used
# by OAuthLoginPage.qml/WebViewPage.qml - couldn't be resolved from this
# sandbox (rpm -qf against the SDK target came up empty for both), check
# via `sfdk engine exec zypper search amber`/`search webview` on a real
# build engine.
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5DBus)
BuildRequires:  desktop-file-utils


%description
Unofficial Mastodon client


%prep
%setup -q -n %{name}-%{version}

%build

%qmake5 

%make_build


%install
%qmake5_install


desktop-file-install --delete-original         --dir %{buildroot}%{_datadir}/applications                %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/applications/%{name}-open-url.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
