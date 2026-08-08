'use strict';
'require view';
'require dom';
'require poll';
'require uci';
'require rpc';
'require form';

return view.extend({
	load: function() {
		return Promise.all([
			uci.changes(),
			uci.load('wireless'),
			uci.load('wizard')
		]);
	},

	render: function(data) {

		var m, s, o;
		var has_wifi = false;
		var splitIPv4CIDR = function(value) {
			var parts, prefix, octets, bits, i;

			if (typeof(value) != 'string' || value.indexOf('/') < 0)
				return null;

			parts = value.split('/');
			if (parts.length != 2 || !parts[0] || !parts[1])
				return null;

			prefix = +parts[1];
			if (prefix < 0 || prefix > 32 || prefix != Math.floor(prefix))
				return null;

			octets = [];
			for (i = 0; i < 4; i++) {
				bits = Math.max(Math.min(prefix - (i * 8), 8), 0);
				octets.push(bits ? 256 - Math.pow(2, 8 - bits) : 0);
			}

			return {
				addr: parts[0],
				netmask: octets.join('.')
			};
		};
		var kmodOption = function(name, title, defaultValue, description) {
			var opt = s.taboption('kmods', form.ListValue, name, title, description);
			opt.default = defaultValue || '1';
			opt.rmempty = false;
			opt.widget = 'radio';
			opt.value('1', _('Load (Keep in filesystem)'));
			opt.value('0', _('Do not load (Delete from filesystem)'));
			return opt;
		};

		if (uci.sections('wireless', 'wifi-device').length > 0) {
			has_wifi = true;
		}

		m = new form.Map('wizard', [_('Router Setup Wizard')],
			_('Configure the basic Internet, local network, IPv6 and optional kernel module settings for this router.'));

		s = m.section(form.NamedSection, 'default', 'wizard');
		s.addremove = false;
		s.tab('wansetup', _('Internet Settings'), _('Choose how this router connects to the Internet.'));
		if (has_wifi) {
			s.tab('wifisetup', _('Wi-Fi Settings'), _('Set the Wi-Fi network name and password. For advanced options, go to Network > Wireless.'));
		}
		s.tab('kmods', _('Kernel Modules'), _('Optional kernel modules that can be enabled or disabled. Modules required by dae and xwan are not shown here and cannot be removed.'));

		o = s.taboption('wansetup', form.ListValue, 'wan_proto', _('Connection type'));
		o.rmempty = false;
		o.default = 'dhcp';
		o.value('dhcp', _('Automatic (DHCP)'));
		o.value('static', _('Static IP address'));
		o.value('pppoe', _('PPPoE'));

		o = s.taboption('wansetup', form.Value, 'wan_pppoe_user', _('PPPoE username'));
		o.depends('wan_proto', 'pppoe');
		o.rmempty = false;

		o = s.taboption('wansetup', form.Value, 'wan_pppoe_pass', _('PPPoE password'));
		o.depends('wan_proto', 'pppoe');
		o.password = true;
		o.rmempty = false;

		o = s.taboption('wansetup', form.Value, 'wan_ipaddr', _('IPv4 address'));
		o.depends('wan_proto', 'static');
		o.datatype = 'ip4addr';
		o.rmempty = false;

		o = s.taboption('wansetup', form.Value, 'wan_netmask', _('IPv4 subnet mask'));
		o.depends('wan_proto', 'static');
		o.datatype = 'ip4addr';
		o.rmempty = false;
		o.value('255.255.255.0');
		o.value('255.255.0.0');
		o.value('255.0.0.0');

		o = s.taboption('wansetup', form.Value, 'wan_gateway', _('IPv4 gateway'));
		o.depends('wan_proto', 'static');
		o.datatype = 'ip4addr';

		o = s.taboption('wansetup', form.DynamicList, 'wan_dns', _('Custom DNS servers'));
		o.datatype = 'ip4addr';
		o.cast = 'string';

		if (has_wifi) {
			o = s.taboption('wifisetup', form.Value, 'wifi_ssid', _('Wi-Fi network name'));
			o.datatype = 'maxlength(32)';

			o = s.taboption("wifisetup", form.Value, "wifi_key", _("Wi-Fi password"));
			o.datatype = 'wpakey';
			o.password = true;
		}

		o = s.taboption('wansetup', form.Value, 'lan_ipaddr', _('LAN IPv4 address'));
		o.datatype = 'ip4addr';
		o.cfgvalue = function(section_id) {
			var value = uci.get('wizard', section_id, 'lan_ipaddr');
			var cidr = splitIPv4CIDR(value);

			return cidr ? cidr.addr : value;
		};

		o = s.taboption('wansetup', form.Value, 'lan_netmask', _('LAN IPv4 subnet mask'));
		o.datatype = 'ip4addr';
		o.value('255.255.255.0');
		o.value('255.255.0.0');
		o.value('255.0.0.0');
		o.cfgvalue = function(section_id) {
			var cidr = splitIPv4CIDR(uci.get('wizard', section_id, 'lan_ipaddr'));

			return cidr ? cidr.netmask : uci.get('wizard', section_id, 'lan_netmask');
		};

		o = s.taboption('wansetup', form.ListValue, 'ipv6', _('IPv6'), _('If disabled, IPv6 services will not be provided on the local network.'));
		o.default = '1';
		o.rmempty = false;
		o.widget = 'radio';
		o.value('1', _('Enable'));
		o.value('0', _('Disable'));

		kmodOption('kmod_wireguard', _('WireGuard (wireguard)'), '1', _('WireGuard VPN encrypted tunnel driver. If you do not use WireGuard, disable it to save memory.'));
		kmodOption('kmod_openvpn_tun', _('TUN / TAP (tun)'), '1', _('TUN/TAP virtual network device driver. The OpenVPN kernel offload module (ovpn) is not available in this firmware kernel.'));
		kmodOption('kmod_alg', _('NAT Helpers / ALG (sip, h323, pptp, ftp, etc.)'), '1', _('Application Layer Gateway (ALG) NAT helpers for legacy protocols such as SIP, H.323, PPTP, FTP, TFTP.'));
		kmodOption('kmod_crypto', _('Cryptodev & AF_ALG (cryptodev, algif_*)'), '1', _('User-space hardware crypto engine (/dev/crypto) and AF_ALG socket crypto interfaces.'));
		kmodOption('kmod_usb', _('USB Core Driver (usbcore, usb-common)'), '1', _('USB core bus driver stack. Can be disabled if the router has no USB ports or no USB devices.'));

		return m.render();
	}
});
