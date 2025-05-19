#!/bin/sh

exec > /root/setup-xidzwrt.log 2>&1

# dont remove !!!
echo "Installed Time: $(date '+%A, %d %B %Y %T')"
sed -i "s#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' / ':'')+(luciversion||''),#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' By Xidz_x':''),#g" /www/luci-static/resources/view/status/include/10_system.js
sed -i -E "s|icons/port_%s.png|icons/port_%s.gif|g" /www/luci-static/resources/view/status/include/29_ports.js
if grep -q "ImmortalWrt" /etc/openwrt_release; then
  sed -i "s/\(DISTRIB_DESCRIPTION='ImmortalWrt [0-9]*\.[0-9]*\.[0-9]*\).*'/\1'/g" /etc/openwrt_release
  sed -i 's|system/ttyd|services/ttyd|g' /usr/share/luci/menu.d/luci-app-ttyd.json
  echo Branch version: "$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')"
elif grep -q "OpenWrt" /etc/openwrt_release; then
  sed -i "s/\(DISTRIB_DESCRIPTION='OpenWrt [0-9]*\.[0-9]*\.[0-9]*\).*'/\1'/g" /etc/openwrt_release
  echo Branch version: "$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')"
fi

# setup login root password
echo "setup login root password"
(echo "xyyraa"; sleep 2; echo "xyyraa") | passwd > /dev/null

# setup hostname and timezone
echo "setup hostname and timezone to asia/jakarta"
uci batch <<EOF
set system.@system[0].hostname='XIDZs-WRT'
set system.@system[0].timezone='WIB-7'
set system.@system[0].zonename='Asia/Jakarta'
delete system.ntp.server
add_list system.ntp.server="pool.ntp.org"
add_list system.ntp.server="id.pool.ntp.org"
add_list system.ntp.server="time.google.com"
commit system
EOF

# setup bahasa default
echo "setup bahasa english default"
uci set luci.@core[0].lang='en'
uci commit

# configure wan and lan
echo "configure wan and lan"
uci batch <<EOF
set network.TETHERING=interface
set network.TETHERING.proto='dhcp'
set network.TETHERING.device='usb0'
set network.WAN=interface
set network.WAN.proto='dhcp'
set network.WAN.device='eth1'
set network.MODEM=interface
set network.MODEM.proto='none'
set network.MODEM.device='wwan0'
delete network.wan6
commit network
set firewall.@zone[1].network='TETHERING WAN'
commit firewall
EOF

# disable ipv6 lan
echo "Disable IPv6 LAN..."
uci -q batch <<EOF
delete dhcp.lan.dhcpv6
delete dhcp.lan.ra
delete dhcp.lan.ndp
EOF
uci commit dhcp

# configure wiireless device
echo "configure wireless 2.4Ghz"
uci set wireless.@wifi-device[0].disabled='0'
uci set wireless.@wifi-iface[0].disabled='0'
uci set wireless.@wifi-device[0].country='ID'
uci set wireless.@wifi-device[0].htmode='HT40'
uci set wireless.@wifi-iface[0].mode='ap'
uci set wireless.@wifi-iface[0].encryption='none'
if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo; then
  uci set wireless.@wifi-device[1].disabled='0'
  uci set wireless.@wifi-iface[1].disabled='0'
  uci set wireless.@wifi-device[1].country='ID'
  uci set wireless.@wifi-device[1].channel='149'
  uci set wireless.@wifi-device[1].htmode='VHT80'
  uci set wireless.@wifi-iface[1].mode='ap'
  uci set wireless.@wifi-iface[1].ssid='XIDZs-WRT_5G'
  uci set wireless.@wifi-iface[1].encryption='none'
else
  uci set wireless.@wifi-device[0].channel='7'
  uci set wireless.@wifi-iface[0].ssid='XIDZs-WRT'
fi
uci commit wireless
wifi reload && wifi up
if iw dev | grep -q Interface; then
  if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo; then
    if ! grep -q "wifi up" /etc/rc.local; then
      sed -i '/exit 0/i # remove if you dont use wireless' /etc/rc.local
      sed -i '/exit 0/i sleep 10 && wifi up' /etc/rc.local
    fi
    if ! grep -q "wifi up" /etc/crontabs/root; then
      echo "# remove if you dont use wireless" >> /etc/crontabs/root
      echo "0 */12 * * * wifi down && sleep 5 && wifi up" >> /etc/crontabs/root
      service cron restart
    fi
  fi
else
  echo "no wireless device detected."
fi

# remove huawei me909s and dw5821e usb-modeswitch"
echo "remove huawei me909s and dw5821e usb-modeswitch"
sed -i -e '/12d1:15c1/,+5d' -e '/413c:81d7/,+5d' /etc/usb-mode.json

# disable xmm-modem
echo "disable xmm-modem"
uci set xmm-modem.@xmm-modem[0].enable='0'
uci commit xmm-modem

# Disable opkg signature check
echo "disable opkg signature check"
sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf

# add custom repository
echo "add custom repository"
echo "src/gz custom_packages https://dl.openwrt.ai/latest/packages/$(grep "OPENWRT_ARCH" /etc/os-release | awk -F '"' '{print $2}')/kiddin9" >> /etc/opkg/customfeeds.conf

# setup default theme
echo "setup tema argon default"
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit

# remove login password ttyd
echo "remove login password ttyd"
uci set ttyd.@ttyd[0].command='/bin/bash --login'
uci commit

# symlink Tinyfm
echo "symlink tinyfm"
ln -s / /www/tinyfm/rootfs

# setup device amlogic
echo "setup device amlogic"
if opkg list-installed | grep -q luci-app-amlogic; then
  echo "luci-app-amlogic detected."
  rm -f /etc/profile.d/30-sysinfo.sh
  sed -i '/exit 0/i #sleep 5 && /usr/bin/k5hgled -r' /etc/rc.local
  sed -i '/exit 0/i #sleep 5 && /usr/bin/k6hgled -r' /etc/rc.local
else
  echo "luci-app-amlogic no detected."
  rm -f /usr/bin/k5hgled /usr/bin/k6hgled /usr/bin/k5hgledon /usr/bin/k6hgledon
fi

# setup misc settings and permission
echo "setup misc settings and permission"
sed -i -e 's/\[ -f \/etc\/banner \] && cat \/etc\/banner/#&/' \
       -e 's/\[ -n "$FAILSAFE" \] && cat \/etc\/banner.failsafe/& || \/usr\/bin\/idz/' /etc/profile
chmod +x /usr/lib/ModemManager/connection.d/10-report-down
chmod -R +x /sbin /usr/bin
chmod +x /root/install2.sh && bash /root/install2.sh

# move jquery.min.js
echo "move jquery.min.js"
mv /usr/share/netdata/web/lib/jquery-3.6.0.min.js /usr/share/netdata/web/lib/jquery-2.2.4.min.js

# setup Auto Vnstat Database Backup
echo "setup auto vnstat database backup"
chmod +x /etc/init.d/vnstat_backup
bash /etc/init.d/vnstat_backup enable

# setup vnstati.sh
echo "setup vnstati.sh"
chmod +x /www/vnstati/vnstati.sh
bash /www/vnstati/vnstati.sh

# restart netdata and vnstat
echo "restart netdata and vnstat"
/etc/init.d/netdata restart
sleep 2
/etc/init.d/vnstat restart

# setup tunnel installed
for pkg in luci-app-openclash luci-app-nikki luci-app-passwall; do
  if opkg list-installed | grep -qw "$pkg"; then
    echo "$pkg detected"
    case "$pkg" in
      luci-app-openclash)
        chmod +x /etc/openclash/core/clash_meta
        chmod +x /etc/openclash/Country.mmdb
        chmod +x /etc/openclash/Geo* 2>/dev/null
        echo "patching openclash overview"
        bash /usr/bin/patchoc.sh
        sed -i '/exit 0/i #/usr/bin/patchoc.sh' /etc/rc.local 2>/dev/null
        ln -s /etc/openclash/history/Quenx.db /etc/openclash/cache.db
        ln -s /etc/openclash/core/clash_meta /etc/openclash/clash
        rm -f /etc/config/openclash
        rm -rf /etc/openclash/custom /etc/openclash/game_rules
        rm -f /usr/share/openclash/openclash_version.sh
        find /etc/openclash/rule_provider -type f ! -name "*.yaml" -exec rm -f {} \;
        mv /etc/config/openclash1 /etc/config/openclash 2>/dev/null           
        ;;
      luci-app-nikki)
        rm -rf /etc/nikki/run/providers
        chmod +x /etc/nikki/run/Geo* 2>/dev/null
        echo "symlink nikki to openclash"
        ln -s /etc/openclash/proxy_provider /etc/nikki/run
        ln -s /etc/openclash/rule_provider /etc/nikki/run
        sed -i -e '64s/'Enable'/'Disable'/' /etc/config/alpha
        sed -i -e '170s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
        ;;
      luci-app-passwall)
        sed -i -e '88s/'Enable'/'Disable'/' /etc/config/alpha
        sed -i -e '171s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
        ;;
    esac
  else
    echo "$pkg no detected"
    case "$pkg" in
      luci-app-openclash)
        rm -f /etc/config/openclash1
        rm -rf /etc/openclash /usr/share/openclash /usr/lib/lua/luci/view/openclash
        sed -i -e '104s/'Enable'/'Disable'/' /etc/config/alpha
        sed -i -e '167s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
        sed -i -e '187s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
        sed -i -e '189s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
        ;;
      luci-app-nikki)
        rm -rf /etc/config/nikki /etc/nikki
        sed -i -e '120s/'Enable'/'Disable'/' /etc/config/alpha
        sed -i -e '168s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
        ;;
      luci-app-passwall)
        rm -f /etc/config/passwall
        sed -i -e '136s/'Enable'/'Disable'/' /etc/config/alpha
        sed -i -e '169s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
        ;;
    esac
  fi
done

# remove storage.js
echo "remove storage.js"
rm -f /www/luci-static/resources/view/status/include/25_storage.js

# Setup uhttpd and PHP8
echo "setup uhttpd and php8"
uci batch <<EOF
set uhttpd.main.ubus_prefix='/ubus'
set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
set uhttpd.main.index_page='cgi-bin/luci'
add_list uhttpd.main.index_page='index.html'
add_list uhttpd.main.index_page='index.php'
commit uhttpd
EOF
sed -i -E "s|memory_limit = [0-9]+M|memory_limit = 128M|g" /etc/php.ini
sed -i -E "s|display_errors = On|display_errors = Off|g" /etc/php.ini
sed -i -E "s|max_execution_time = [0-9]+|max_execution_time = 120|g" /etc/php.ini
sed -i -E "s|max_input_time = [0-9]+|max_input_time = 120|g" /etc/php.ini
ln -sf /usr/bin/php-cli /usr/bin/php
[ -d /usr/lib/php8 ] && [ ! -d /usr/lib/php ] && ln -sf /usr/lib/php8 /usr/lib/php
/etc/init.d/uhttpd restart

echo "all setup complete"
rm -rf /etc/uci-defaults/$(basename $0)

exit 0
