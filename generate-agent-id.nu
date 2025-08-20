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

print $agent_id
if ( not (($agent_id | str length ) == 40 ) ) {
	print "Error: agent_id is not 40 characters long"
	exit 1
}