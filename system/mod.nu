# System information module

# List network interfaces, excluding localhost and link-local addresses
export def net [] {
	sys net
	| update ip {|row|
		$row.ip | where {|it|
			($it.address not-in ['127.0.0.1', '::1']
			and $it.address !~ '^fe80::')
		}
	}
	| where ($it.ip | length) > 0
	| sort-by name
}
