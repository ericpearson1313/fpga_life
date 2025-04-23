
# format_commit.awk - format git commit id for insttion into flash_rom.mif
# awk used to format git commmit id into three lines of a mif file. ie:
# Run after checkout, before synthesis to embed commit into video overlay lower right corner
#
# git rev-parse HEAD | head -c7 | basenc --base2msbf --wrap=8 | awk -f format_commit.aw
# 
# The 3 liens of output replace the lines 1958,+3 in the flash_rom.mif
# upon checkout are: [0123abc]
# 79d : 00000011000000000011000100000011;
# 79e : 00100000001100110000011000010000;
# 79f : 01100010000001100011000001011101;

BEGIN { # read the 7 lines of 8 bits from masenc command
	getline; b0 = $0;
	getline; b1 = $0;
	getline; b2 = $0;
	getline; b3 = $0;
	getline; b4 = $0;
	getline; b5 = $0;
	getline; b6 = $0;
	# format them for a mif file substiturion
	print "79d : 0000" b0 "0000" b1 "0000" substr( b2, 1, 4) ";"
	print "79e : " substr( b2, 5, 4 ) "0000" b3 "0000" b4 "0000;"
	print "79f : " b5 "0000" b6 "000001011101;"
}
