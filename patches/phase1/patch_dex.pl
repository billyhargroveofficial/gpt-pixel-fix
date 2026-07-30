#!/usr/bin/env perl

use strict;
use warnings;
use Digest::SHA qw(sha1);
use Compress::Zlib qw(adler32);

sub usage {
    die "usage: $0 INPUT.dex OUTPUT.dex OFFSET:OLD_HEX:NEW_HEX [...]\n";
}

@ARGV >= 3 or usage();
my ($input, $output, @patches) = @ARGV;

open my $in, '<:raw', $input or die "cannot open $input: $!\n";
local $/;
my $dex = <$in>;
close $in or die "cannot close $input: $!\n";

substr($dex, 0, 8) eq "dex\n037\0"
    or die "$input is not a dex\\n037 file\n";

for my $patch (@patches) {
    my ($offset_text, $old_hex, $new_hex) =
        $patch =~ /\A(0x[0-9a-fA-F]+|[0-9]+):([0-9a-fA-F]+):([0-9a-fA-F]+)\z/
        or usage();

    length($old_hex) == length($new_hex)
        or die "patch $patch changes file size\n";
    length($old_hex) % 2 == 0
        or die "patch $patch has an odd hex length\n";

    my $offset = $offset_text =~ /\A0x/ ? hex($offset_text) : int($offset_text);
    my $old = pack 'H*', $old_hex;
    my $new = pack 'H*', $new_hex;

    substr($dex, $offset, length($old)) eq $old
        or die sprintf("unexpected bytes at 0x%x in %s\n", $offset, $input);
    substr($dex, $offset, length($old), $new);
}

# DEX signature covers everything after the 32-byte header prefix.
substr($dex, 12, 20, sha1(substr($dex, 32)));

# DEX Adler-32 covers the signature and everything after it.
substr($dex, 8, 4, pack('V', adler32(substr($dex, 12))));

open my $out, '>:raw', $output or die "cannot create $output: $!\n";
print {$out} $dex or die "cannot write $output: $!\n";
close $out or die "cannot close $output: $!\n";
