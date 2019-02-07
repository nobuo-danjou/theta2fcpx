#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use File::Basename;
use Path::Class;
use URI::file;
use Time::Piece;
use File::Temp;

my $time = localtime;

my $blender = '/Applications/RICOH\ THETA.app/Contents/Resources/tools/dualfishblender/osx/DualfishBlender.osx';
my $converter = '/Applications/RICOH\ THETA\ Movie\ Converter.app/Contents/MacOS/RICOH\ THETA\ Movie\ Converter';

my @clips;

my $basedir = Path::Class::File->new($ARGV[0])->dir;

my $id = 0;
for my $arg (@ARGV) {
    my $file = Path::Class::File->new($arg);
    $file->stat or next;
    my $basename = basename($file, '.MP4');
    my $blended = Path::Class::File->new($file->dir, sprintf('%s_er.MP4', $basename));
    my $converted = Path::Class::File->new($file->dir, sprintf('%s_er.mov', $basename));
    system("$blender $file $blended") unless $blended->stat;
    system("$converter $blended $converted") unless $converted->stat;
    push @clips, {path => $converted, name => $basename, id => sprintf("r%d", ++$id)};
}

my $template = <<END;
<?xml version="1.0"?>
<fcpxml version="1.8">
<import-options>
<option key="library location" value="%s"/>
<option key="copy assets" value="0"/>
</import-options>
<resources>
%s
</resources>
%s
</fcpxml>
END

my $xml = sprintf($template,
    URI::file->new_abs($basedir->file(sprintf('theta2fcpx_%d.fcpbundle/', $time->strftime('%Y%m%d%H%M%S')))->absolute),
    map({sprintf(qq(<asset id="%s" name="%s" src="%s"/>\n), $_->{id}, $_->{name}, URI::file->new_abs($_->{path}->absolute))} @clips),
    map({sprintf(qq(<asset-clip name="%s" ref="%s"/>\n), $_->{name}, $_->{id})} @clips)
);
my $fh = File::Temp->new(SUFFIX => '.fcpxml');
print $fh $xml;
close $fh;
my $fcpxml = $fh->filename;
system(qq(osascript -e 'tell application "Final Cut Pro" to open "$fcpxml"' >/dev/null));
