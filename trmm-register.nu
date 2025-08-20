#!/usr/bin/env nu

$env.NU_LOG_LEVEL = "DEBUG"
let trmm_api_host = 'api.a8n.tools'
let hostname = (sys host | get hostname)
let description = (input "Enter node description: ")

mut answered = false 
mut monitoring_type = ''
while ( not ($answered) ) {
	mut answer = (input "Enter monitoring type (s)erver/(w)orkstation: ")
	if ( $answer == "s" or $answer == "w" ) {
		$answered = true
		$monitoring_type = if ($answer == "s") { 'server' } else { 'workstation' }
	} else {
		print $"Invalid monitoring type. Please enter 's' for server or 'w' for workstation."
	}
}

let trmm_api_key = (input "Enter TRMM API Key: ")
let trmm_register_key = (input "Enter TRMM Register Key: ")

if ($trmm_api_key == "" or $trmm_register_key == "") {
	print "API Key or Register Key cannot be empty. Exiting."
	exit 1
}


# let trmm_register_path = '/agents/'

let headers = [
	# TODO: Make this dynamic
	"Content-Type" "application/json"
	# This does not work when running /runscript/ against the api.
	# "Content-Type" "application/x-www-form-urlencoded"
	"X-API-KEY" $trmm_api_key
	"Authorization" $"Token ($trmm_register_key)"
]

let post_url = (
	{
		scheme: https,
		host: $trmm_api_host,
		path: '/api/v3/newagent/'
	} | url join
)

let options = {
	# https://www.nushell.sh/commands/docs/http_get.html
	# timeout period in seconds
	max_time: (5sec | into duration)
}

let agent_id = (
	0..39
	| each {
		let chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
		# grab a random index for the legnth between 0 and 51
		let idx = (random int 0..<52)
		# get the character at the random index
		$chars | str substring $idx..<($idx + 1)
	}
	| str join
)


let agent_payload = {
	# agent_id is a randomly generated 40-character string of upper and lowercase letters.
	# https://github.com/amidaware/rmmagent/blob/develop/agent/utils.go#L134
	"agent_id":        $agent_id,
	"hostname":        $hostname,
	"site":            1,
	"monitoring_type": 'server',
	"mesh_node_id":    '',
	"description":     $description,
	"goarch":          'amd64',
	"plat":            'linux',
}

#1. Create a TacticalRMM agent with the information created.
# http get --max-time $options.max_time --headers $headers $url
let post_body = ($agent_payload | to json --raw)
let post_result = http post --allow-errors --full --max-time $options.max_time --headers $headers $post_url $post_body


#2. Take the current configuration in /etc/tacticalrmm
let agentpk = ($post_result.body.pk)
let token = ($post_result.body.token)
let tacticalagent = {
	"agentid": $agent_id,
	"agentpk": $agentpk,
	"apiurl": $trmm_api_host,
	"baseurl": ( { scheme: https, host: $trmm_api_host } | url join)
	"cert": "",
	"meshdir": "",
	"natsstandardport": "",
  	"proxy": "",
	"token": $token
}

if ( "/etc/tacticalagent" | path exists ) {
	^sudo cp "/etc/tacticalagent" "/etc/tacticalagent.bak"
}

$tacticalagent | to json | ^sudo tee "/etc/tacticalagent" | ignore

# 3. restart tacticalrmm
^sudo systemctl restart tacticalagent

$tacticalagent