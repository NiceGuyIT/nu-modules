# Use this shebang to check the script for errors.
# #!/usr/bin/env -S nu --ide-check 1

export-env {
	# Module name, used to load the configuration.
	$env.MODULE_NAME = "tactical-rmm"

	# Set the log level and file.
	$env.NU_LOG_LEVEL = "DEBUG"
	
	# Output log is not currently used. Instead, use this to call the program.
	#   script.nu err>| save --force output.log
	$env.NU_LOG_FILE = false
}

# Load the configuration file
def "load config" []: string -> any {
	let name = $in
	if ("TRMM_API_HOST" in $env) and ("TRMM_API_KEY" in $env) {
		{
			host: $env.TRMM_API_HOST
			api_key: $env.TRMM_API_KEY
		}
	} else if ($env.HOME | path join ".config/sops" $"($name).nuon" | path exists) {
		($env.HOME | path join ".config/sops" $"($name).nuon") | open | get config?.file? | open
	} else if ($env.HOME | path join ".config/sops" $"($name).yml" | path exists) {
		($env.HOME | path join ".config/sops" $"($name).yml") | open | get config?.file? | open
	} else if ($env | get --ignore-errors ([$name, "_CONFIG"] | str join | str upcase) | path exists) {
		$env | get --ignore-errors ([$name, "_CONFIG"] | str join | str upcase) | open | get config?.file? | open
	}
}

# Connect to TRMM. --env allows exporting environment variables.
export def --env "trmm connect" [
	--json-connection: string,		# JSON file that contains the host and API key
]: nothing -> nothing {
	# tactical-rmm.yml file format:
	# host: api.example.com
	# api_key: API_KEY_HERE
	use std log
	log debug $env.MODULE_NAME
	let config = ($env.MODULE_NAME | load config)

	# Save the connection details in an environment variable.
	$env.TRMM = {
		# HTTP headers as an array.
		# "X-API-KEY XXX" is for API keys.
		# "Authorization Token XXX" is for agent authorization.
		headers: [
			# TODO: Make this dynamic
			"Content-Type" "application/json"
			# This does not work when running /runscript/ against the api.
			# "Content-Type" "application/x-www-form-urlencoded"
			"X-API-KEY" $config.api_key
		]
		# Used in url join
		# https://www.nushell.sh/commands/docs/url_join.html
		url: {
			scheme: https,
			host: $config.host,
		}
		options: {
			# https://www.nushell.sh/commands/docs/http_get.html
			# timeout period in seconds
			max_time: (5sec | into duration)
		}
	}
}

# Helper function for GET requests to TRMM.
export def "trmm get" [
	path: string,				# URL path to get
	query: string = "",			# URL query string
]: nothing -> any {
	mut url = ""
	if ($query | is-not-empty) {
		$url = ({...$env.TRMM.url, path: $path, query: $query} | url join)
	} else {
		$url = ({...$env.TRMM.url, path: $path} | url join)
	}
	http get --max-time $env.TRMM.options.max_time --headers $env.TRMM.headers $url
}

# Helper function for PUT requests to TRMM. $in is the body.
export def "trmm put" [
	path: string,				# URL path to get
	query: string = nil,		# URL query string
]: any -> any {
	let input = $in
	let trmm = $env.TRMM
	http put --max-time $trmm.options.max_time --headers $trmm.headers (
		{...$trmm.url, path: $path, query: $query} | url join
	) $input
}

# Helper function for POST requests to TRMM. $in is the body.
export def "trmm post" [
	path: string,				# URL path to get
	query: string = "",		# URL query string
]: any -> any {
	let input = $in
	let trmm = $env.TRMM
	# use std log
	# log debug $"[trmm post] input: ($input)"
	http post --max-time $trmm.options.max_time --headers $trmm.headers (
		{...$trmm.url, path: $path, query: $query} | url join
	) $input

	# let url = ({...$trmm.url, path: $path, query: $query} | url join)
	# print $"http post --max-time ($trmm.options.max_time) --headers ($trmm.headers) ($url) ($input)"
}

# Get all agents, minus their details.
export def "trmm agents" [
	--details = false			# Provide the details?
]: nothing -> any {
	let input = $in
	let details = $details
	if ($input | is-not-empty) {
		$input | each {|it|
			# TODO: $it assumes the raw agent_id is $input. Should it allow $it.agent_id?
			trmm get $"/agents/($it)/" $"details=($details)"
		}
	} else {
		# trmm get "/agents/" $"details=false"
		trmm get "/agents/" $"details=($details)"
		# trmm get "/agents/"
	}
}

# Get all agents and their custom fields.
export def "trmm agent customfields" []: any -> any {
	# TRMM connection details are input.
	let input = $in
	# Get all custom fields to be used as a lookup.
	let custom_fields = ($input | trmm core customfields)

	# Get the agents and their custom fields. Note: The custom fields are only IDs, not names.
	$input | trmm agents | each {|it|
		# Nushell variables are immutable by default (using "let").
		# https://www.nushell.sh/book/thinking_in_nu.html#variables-are-immutable
		# $agent needs to be mutable so it can be assigned.
		mut agent = ($it | select agent_id hostname site_name client_name custom_fields)
		$agent.custom_fields = ($agent.custom_fields | each {|f|
			let left = ($f | select id field agent value)
			let right = ($custom_fields | where id == $f.field | select id model name | get 0)
			# merge will merge two records or tables
			# https://www.nushell.sh/commands/docs/merge.html
			$left | merge $right | select agent model name value
		})
		$agent
	}
}

# Update Nushell for one agent.
export def "trmm agent nushell update" []: any -> any {
	let input = $in
	if ($input | is-not-empty) {
		log info $"Input: ($input)"
		$input | each {|it|
			# TODO: $it assumes the raw agent_id is $input. Should it allow $it.agent_id?
			'{
				"shell": "cmd",
				"cmd": "nu version",
				"timeout": 30,
				"custom_shell": "nushell",
				"run_as_user": false
			}'
			| trmm post $"/agents/($it)/cmd/"
		}
	} else {
		trmm get "/agents/"
	}
}

# Run a script on an agent.
export def "trmm script run" [
	agent_id: string			# Agent to run the script on
]: any -> any {
	let input = $in
	if ($input | is-empty) {
		use std log
		log warning "Input (script payload)is empty"
		return
	}

	# Input payload
	# {
	# 	"output": "wait",
	# 	"emails": [],
	# 	"emailMode": "default",
	# 	"custom_field": null,
	# 	"save_all_output": false,
	# 	"script": 123,
	# 	"args": [],
	# 	"env_vars": [
	# 		"VAR1=value1",
	# 		"VAR2=value2"
	# 	],
	# 	"timeout": 90,
	# 	"run_as_user": false,
	# 	"run_on_server": false
	# }

	# use std log
	# log debug $"[trmm script run] Input: ($input)"
	# log debug $"[trmm script run] agent_id: ($agent_id)"

	$input
	| to json --raw
	| trmm post $"/agents/($agent_id)/runscript/"
}

# Get all custom fields.
export def "trmm core customfields" []: nothing -> any {
	trmm get "/core/customfields/"
}

# Get the Windows updates for agents
export def "trmm winupdate" []: any -> any {
	where plat == "windows" | each {|it|
		trmm get $"/winupdate/($it.agent_id)/"
	} | flatten
}

# Get the Windows updates that are not installed
export def "trmm winupdate pending" []: any -> any {
	where plat == "windows" | each {|it|
		trmm get $"/winupdate/($it.agent_id)/"
			| where installed == false
	} | flatten
}

# Approve Windows updates
export def "trmm winupdate approve" []: any -> any {
	each {|it|
		{action: approve} | to json | trmm put $"/winupdate/($it.id)/"
	} | flatten
}

# Install Windows updates
export def "trmm winupdate install" []: any -> any {
	where plat == "windows" | each {|it|
		null | to json | trmm post $"/winupdate/($it.agent_id)/install/"
	} | flatten
}

############################################################
# Functions for the Tactical Agent binary
############################################################

# Get the TRMM agent version.
export def "trmm-agent version" []: string -> table<name: string, version: string> {
	let agent_bin = $in
	if not ($agent_bin | path exists) {
		log error $"Agent binary not found: '($agent_bin)'"
		return null
	}
	^$agent_bin -version | lines | where $it =~ "Tactical RMM Agent" | split column ':' | rename name version
}

# Create the systemd service for TRMM.
export def "trmm-agent service create" [
	--service-name: string = "tacticalagent"		# Systemd service name for the Tactical Agent service
]: [string -> string, string -> nothing] {
	let service_bin = $in
	let service_name = $service_name
	let service_filename = $"/etc/systemd/system/($service_name).service"

	let tactical_service = $"[Unit]
Description=Tactical RMM Linux Agent

[Service]
Type=simple
ExecStart=($service_bin) -m svc
User=root
Group=root
Restart=always
RestartSec=5s
LimitNOFILE=1000000
KillMode=process

[Install]
WantedBy=multi-user.target
"

	use std log
	log info $"Installing ($service_name) service"
	if (whoami) != "root" {
		$tactical_service | ^sudo tee $service_filename
		^sudo chmod a+r $service_filename
		^sudo systemctl daemon-reload
		^sudo systemctl enable --now $"($service_name).service"
	} else {
		$tactical_service | save --force $service_filename
		^chmod a+r $service_filename
		^systemctl daemon-reload
		^systemctl enable --now $"($service_name).service"
	}
}


# Install Tactical RMM using an existing tacticalagent binary.
export def "trmm-agent install" [
	--api-domain: string,					# Tactical API URL
	--client-id: int = 1,					# Client ID for the agent
	--site-id: int = 1,						# Site ID for the agent
	--agent-type: string = "server"			# server or workstation
	--agent-bin: path = "tacticalagent"		# Path to TRMM agent binary
]: nothing -> nothing {
	let api_domain = $api_domain
	let client_id = $client_id
	let site_id = $site_id
	let agent_type = $agent_type
	let agent_bin = ($agent_bin | path expand)

	# The tacticalagent binary needs to be in the current directory.
	if not ($agent_bin | path exists) {
		log error $"Agent binary not found: '($agent_bin)'"
		return
	}
	let agent_version = ($agent_bin | trmm-agent version)

	# Tactical agent service name
	let tacticalagent_name = "tacticalagent"
	let tacticalagent_path = ("/usr/local/bin" | path join $tacticalagent_name)

	# Prompt for the auth secret
	let agent_auth = (input --suppress-output "Please enter the auth code for Tactical: ")
	print ""
	print ""
	if (whoami) != "root" {
		# Remove previous config if it exists
		if ("/etc/tacticalagent" | path exists) {
			^sudo rm "/etc/tacticalagent"
		}
		^sudo $agent_bin ...[
			-m install
			-api ({scheme: "https", host: $api_domain} | url join)
			-client-id $client_id
			-site-id $site_id
			-agent-type $agent_type
			-auth $agent_auth
		]

		# "Install" the binary
		^sudo cp $agent_bin $tacticalagent_path
		^sudo chmod o+r,a+x $tacticalagent_path

	} else {
		# Remove previous config if it exists
		if ("/etc/tacticalagent" | path exists) {
			rm "/etc/tacticalagent"
		}
		^$agent_bin ...[
			-m install
			-api ({scheme: "https", host: $api_domain} | url join)
			-client-id $client_id
			-site-id $site_id
			-agent-type $agent_type
			-auth $agent_auth
		]

		# "Install" the binary
		cp $agent_bin $tacticalagent_path
		^chmod o+r,a+x $tacticalagent_path

	}

	$tacticalagent_path | trmm-agent service create --service-name $tacticalagent_name
}

def generate-agent-id []: any -> string {
	# Generate a random 40-character string of upper and lowercase letters.
	#(
	const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
	let agent_id = ( 0..39
		| each {
			# grab a random index for the legnth between 0 and 51
			let idx = (random int 0..<52)
			# get the character at the random index
			$chars | str substring $idx..<($idx + 1)
		}
		| str join )

	return $agent_id
}

# Registers trmm agent using the TacticalRMM API, updates the config and restarts the service.
export def "trmm-agent register" [ 
	--api-domain: string,					# Tactical API URL
	--client-id: int = 1,					# Client ID for the agent
	--site-id: int = 1,						# Site ID for the agent
	--agent-type: string = "server",		# server or workstation
]: nothing -> any {
	use std log

	# Flag variables
	let api_domain = $api_domain
	let client_id = $client_id
	let site_id = $site_id
	let agent_type = $agent_type

	const agent_config_file = '/etc/tacticalagent'
	const api_new_agent_path = "/api/v3/newagent/"
	const trmm_service_name = 'tacticalagent'

	# For the moment, this function is linux only
	if $nu.os-info.name != 'linux' {
		log error $"Only Linux is supported at the time. OS: '($nu.os-info.name)'"
		return
	}

	if not (is-admin) {
		log error $"This command must be run as an admin user. user: '($env.USER)'"
		return
	}

	if not ($agent_config_file | path exists) {
		log error $"Tactical Agent configuration not found in '($agent_config_file)'"
		return
	}

	# The install token pulls from the environment first and falls back to user input.
	log info "Registering TacticalRMM agent"
	if not ('TRMM_INSTALL_TOKEN' in $env) or ($env.TRMM_INSTALL_TOKEN | is-empty) {
        log error "Installation token cannot be empty. Exiting."
        return
	}

	# The install token is the agent installation token used to authenticate with the API.
    $env.TRMM.headers = ($env.TRMM.headers | append [ 
		"Authorization" $"Token ($env.TRMM_INSTALL_TOKEN )"
	])

	# agent_id is a randomly generated 40-character string of upper and lowercase letters.
	# https://github.com/amidaware/rmmagent/blob/develop/agent/utils.go#L134
	let agent_id = (generate-agent-id)
    let agent_payload = {
        "agent_id":        $agent_id,
        "hostname":        (sys host | get hostname),
        "site":            $site_id,
        "monitoring_type": $agent_type,
        "mesh_node_id":    '',
        "description":     '',
		# Convert from Rust arch to Golang arch
		# https://github.com/NiceGuyIT/dotfiles/blob/684ecf953c31241cedd903e6054008935d6b7ecd/private_dot_config/nushell/modules/package/mod.nu#L191
        "goarch":          'amd64',
        "plat":            $nu.os-info.name,
    }

    # 1. Create a TacticalRMM agent with the information created.
    let response = (
		$agent_payload | to json --raw | trmm post $api_new_agent_path
	)

    # 2. Take the current configuration in /etc/tacticalrmm
	log info $"($response)"
	if ($response.pk? | is-empty) or ($response.token? | is-empty) {
		log error $"Body does not have the pk or token. response: '($response)'"
		return
	}

	let agent_config_backup = (
		{
			stem: $agent_config_file,
			extension: (open $agent_config_file | from json | get apiurl)
		} | path join
	)
	log info $"Backing up agent config to '($agent_config_backup)'"
	cp $agent_config_file $agent_config_backup

	open $agent_config_file
	| from json
	| update agentid $agent_id
	| update agentpk $response.pk
	| update apiurl $env.TRMM.url.host
	| update baseurl ( { scheme: https, host: $env.TRMM.url.host } | url join )
	| update token $response.token
	| collect
	| to json --raw
	| save $agent_config_file --force

    # 3. restart tacticalrmm
    ^systemctl restart $"($trmm_service_name).service"

    return (open $agent_config_file | from json)
}


# Download Mesh Agent.
export def "meshexe" [
	--agent-bin: path = "meshexe"			# Path to TRMM agent binary
]: nothing -> nothing {
	let config = ($env.MODULE_NAME | load config)
	let headers = [ "Content-Type" "application/x-www-form-urlencoded" "X-API-KEY" $config.api_key ]
	let body = {
		goarch: 'amd64'
		plat: 'windows'
	}
	let path = "/api/v3/meshexe/"
	let url = ({...$env.TRMM.url, path: $path} | url join)

	# $body | to json | trmm post $path | reject body
	$body | http post --full --allow-errors --redirect-mode manual --content-type "multipart/form-data" --headers $headers $url
}
