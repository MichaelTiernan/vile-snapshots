#   Breadcrumbs.pm (version 0.2) - Provides named placeholders for Vile.
#
#   Copyright (C) 2001  J. Chris Coppick
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

package Breadcrumbs;

my $DEFAULT_DATABASE = "$ENV{'HOME'}/.vilecrumbs";

use locale;
use DB_File;
use Vile;
use Vile::Manual;
require Vile::Exporter;

@ISA = 'Vile::Exporter';
%REGISTRY = (
    'dropcrumb'  => [\&drop, 'mark a place in a file' ],
    'findcrumb' => [\&find, 'given a mark name, go to that file/place' ],
    'eatcrumb' => [\&delete, 'given a mark name, delete that breadcrumb' ],
    'showcrumbs' => [\&show, 'create a buffer listing all breadcrumbs' ],
    'loadcrumbs' => [\&merge, 'load & merge marks from a given DB file' ],
    'unloadcrumbs' => [\&unmerge, 'unload marks from a given DB file' ],
    'breadcrumbs-help' => [sub {&manual}, 'manual page for Breadcrumbs.pm' ]
);


sub drop {

   my $crumbfile = crumbDB();
   my %crumbs;

   my $cb = $Vile::current_buffer;
   my $filename = $cb->filename;
   my $size = length($filename);
   my ($ln,$off) = $cb->dot;

   if (!$size) {
      print "Cannot drop crumb in anonymous buffer.  Sorry.";
      return 0;
   }

   my $label = Vile::mlreply_no_opts("Crumb? ");
   return 0 if (!defined($label) || $label eq '' || $label =~ /^\s*$/);

   chomp($label);

   my $crumb = pack("i a${size} i i", $size, $filename, $ln, $off);

   my $hash = new DB_File::HASHINFO;
   $hash->{'bsize'} = 512;
   $hash->{'cachesize'} = 512;
   tie(%crumbs, 'DB_File', $crumbfile, O_CREAT|O_RDWR, 0600, $hash) || do {
      print "Couldn't open breadcrumb database $crumbfile: $!";
      return 1;
   };

   if (defined($crumbs{$label})) {
      my $ans = '';
      while ($ans !~ /^[yYnN]/) {
	 $ans =
	   Vile::mlreply_no_opts("\"$label\" already used.  Reuse $label? (Y/N): ");
      }
      return 0 if ($ans =~ /^[nN]/);
   }

   $crumbs{$label} = $crumb;

   untie(%crumbs);

   show(1) if (defined($_been_here));

   return 0;
}

sub find {

   my $crumbfile = crumbDB();
   my %crumbs;

   my $hash = new DB_File::HASHINFO;
   tie(%crumbs, 'DB_File', $crumbfile, O_RDONLY, 0600, $hash) || do {
      print "Couldn't open breadcrumb database $crumbfile: $!";
      return 1;
   };

   my $label = Vile::mlreply_no_opts("Crumb? ");
   return 0 if (!defined($label) || $label eq '' || $label =~ /^\s*$/);

   chomp($label);

   if (!defined($crumbs{$label})) {
      print "No such breadcrumb: $label";
      untie(%crumbs);
      return 0;
   }

   my $size = unpack("i", $crumbs{$label});
   my ($size, $filename, $ln, $off) =
      unpack("i a${size} i i", $crumbs{$label});

   untie(%crumbs);

   if (!defined($filename) ||
       $filename eq '' ||
       !defined($ln) ||
       !defined($off)) {

      print "Soggy breadcrumb - bad data retrieval for crumb $label";
   }

   $Vile::current_buffer = new Vile::Buffer "$filename";
   ($Vile::current_buffer)->dot($ln, $off);

   return 0;
}

sub delete {

   my $crumbfile = crumbDB();
   my %crumbs;

   my $hash = new DB_File::HASHINFO;
   tie(%crumbs, 'DB_File', $crumbfile, O_RDWR, 0600, $hash) || do {
      print "Couldn't open breadcrumb database $crumbfile: $!";
      return 1;
   };

   my $label = Vile::mlreply_no_opts("Crumb? ");
   return 0 if (!defined($label) || $label eq '' || $label =~ /^\s*$/);

   chomp($label);

   if (!defined($crumbs{$label})) {
      print "No such breadcrumb: $label";
      untie(%crumbs);
      return 0;
   }

   delete $crumbs{$label};

   print "Deleted breadcrumb: $label";

   untie(%crumbs);

   show(1) if (defined($_been_here));

   return 0;
}


sub show {

   my $stealth = @_;

   my $crumb, $label, $filename, $ln, $off;
   my $buf;
   my $visible = 0;
   my $crumbs = getcrumbs();

   if (defined($_been_here)) {
      if ($stealth) {
	 my $i, $win;
	 for ($i = 0; $i < Vile::window_count; $i++) {
	    $win = Vile::window_at $i;
	    $buf = $win->buffer();
	    if ($buf->buffername() eq "[Breadcrumbs]") {
	       if (Vile::window_count > 1) {
		  $win->delete();
		  if ($i) {
		     $win = Vile::window_at 0;
		  } else {
		     $win = Vile::window_at 1;
		  }
		  $win->current_window();
		  $Vile::current_buffer = $win->buffer();
		  Vile::update();
	       }
	       $visible++;
	       last;
	    }
	 }
      } else {
	 $visible++;
      }
      Vile::command "kill-buffer [Breadcrumbs]";
      undef $_been_here;
      Vile::update();

      if ($stealth && !$visible) {

	 # There was a list buffer, but we've killed it and since it
	 # wasn't visible anyway and the user didn't call us directly,
	 # we're done here.
	 return 0;
      }

   } else {
      $visible++;
   }


   if (!defined($crumbs)) {
      return 1;			# getcrumbs had a boo boo.
   }

   if (!%$crumbs) {
      print "No crumbs found" if (!$stealth);
      return 0;
   }

   $buf = new Vile::Buffer;
   $buf->buffername('[Breadcrumbs]');
   $_been_here = $buf;

   my $osav = select($buf);

   printf "%-20s%-40s%-10s%-10s\n", "Breadcrumb", "Filename", "Line", "Offset";
   printf "%-20s%-40s%-10s%-10s\n", "----------", "--------", "----", "------";

   if (Vile::get('%breadcrumbs_nosort') == 1) {
      while (($label, $crumb) = each(%$crumbs)) {
	 $filename = $$crumb{'filename'};
	 split(/\//,$filename);
	 $filename = $_[$#_];
	 $ln = $$crumb{'line'};
	 $off = $$crumb{'offset'};
	 printf "%-20s%-40s%-10s%-10s\n", $label, $filename, $ln, $off;
      }
   } else {

      my @larray = sort(keys %$crumbs);
      while ($label = shift @larray) {
	 next if ($label eq '' || $label =~ /^\s*$/);
	 $crumb = $$crumbs{$label};
	 $filename = $$crumb{'filename'};
	 split(/\//,$filename);
	 $filename = $_[$#_];
	 $ln = $$crumb{'line'};
	 $off = $$crumb{'offset'};
	 printf "%-20s%-40s%-10s%-10s\n", $label, $filename, $ln, $off;
      }
   }

   Vile::update;


   select($osav);
   $buf->set('view');
   $buf->unmark;
   $buf->dot(0, 0);
   if ($visible) {
      new Vile::Window $buf;
      $Vile::current_buffer = $buf if (!$stealth);
   }

   return 0;
}

sub getcrumbs {

   my $label, $crumb;
   my $size, $filename, $ln, $off;
   my %crumblist, $hr;
   my %crumbs;

   my $crumbfile = crumbDB();

   my $hash = new DB_File::HASHINFO;
   tie(%crumbs, 'DB_File', $crumbfile, O_RDONLY, 0600, $hash) || do {
      print "Couldn't open breadcrumb database $crumbfile: $!";
      return undef;
   };

   while (($label, $crumb) = each(%crumbs)) {
      last if ($label eq '');
      $size = unpack("i", $crumb);
      ($size, $filename, $ln, $off) = unpack("i a${size} i i", $crumb);

      if (!defined($filename) ||
	  $filename eq '' ||
	  !defined($ln) ||
	  !defined($off)) {

	 print "Soggy breadcrumb - bad data retrieval for crumb $label";
	 return undef;
      }

      $hr = { 'filename' => $filename,
              'line' => $ln,
	      'offset' => $off };
      $crumblist{$label} = $hr;
   }

   untie(%crumbs);

   return \%crumblist;
}

sub merge {
   my $crumbfile = crumbDB();
   my %crumbs, %newcrumbs;
   my $label, $crumb;

   my $hash = new DB_File::HASHINFO;
   $hash->{'bsize'} = 512;
   $hash->{'cachesize'} = 512;
   tie(%crumbs, 'DB_File', $crumbfile, O_CREAT|O_RDWR, 0600, $hash) || do {
      print "Couldn't open breadcrumb database $crumbfile: $!";
      return 1;
   };

   my $loadfile = Vile::mlreply_no_opts("Crumb File? ");
   return 0 if (!defined($loadfile) || $loadfile eq '' || $loadfile =~ /^\s*$/);

   chomp($loadfile);
   my $hash2 = new DB_File::HASHINFO;
   tie(%newcrumbs, 'DB_File', $loadfile, O_RDONLY, 0600, $hash2) || do {
      print "Couldn't open breadcrumb database $loadfile: $!";
      return 1;
   };

   print "Loading crumbs from $loadfile...";
   while (($label, $crumb) = each(%newcrumbs)) {
      next if (!defined($label) || $label eq '' || $label =~ /^\s*$/);

      if (defined($crumbs{$label})) {
	 my $ans = '';
	 while ($ans !~ /^[yYnN]/) {
	    $ans =
	      Vile::mlreply_no_opts("\"$label\" already used.  Overwrite $label? (Y/N): ");
	 }
	 if ($ans =~ /^[yY]/) {
	    $crumbs{$label} = $crumb;
	 }

      } else {
	 $crumbs{$label} = $crumb;
      }
   }
   untie %crumbs;
   untie %newcrumbs;

   print "Load complete.";

   show(1) if (defined($_been_here));

   return 0;
}

sub unmerge {
   my $crumbfile = crumbDB();
   my %crumbs, %badcrumbs;
   my $label, $crumb;
   my $size, $filename1, $ln1, $off1;
   my $filename2, $ln2, $off2;

   my $hash = new DB_File::HASHINFO;
   tie(%crumbs, 'DB_File', $crumbfile, O_RDWR, 0600, $hash) || do {
      print "Couldn't open breadcrumb database $crumbfile: $!";
      return 1;
   };

   my $loadfile = Vile::mlreply_no_opts("Crumb File? ");
   return 0 if (!defined($loadfile) || $loadfile eq '' || $loadfile =~ /^\s*$/);

   chomp($loadfile);
   my $hash2 = new DB_File::HASHINFO;
   tie(%badcrumbs, 'DB_File', $loadfile, O_RDONLY, 0600, $hash2) || do {
      print "Couldn't open breadcrumb database $loadfile: $!";
      return 1;
   };

   print "Unloading...";
   while (($label, $crumb) = each(%badcrumbs)) {
      next if (!defined($label) || $label eq '' || $label =~ /^\s*$/);

      if (defined($crumbs{$label})) {
	 $size = unpack("i", $crumb);
	 ($size, $filename1, $ln1, $off1) = unpack("i a${size} i i", $crumb);
	 $size = unpack("i", $crumbs{$label});
	 ($size, $filename2, $ln2, $off2) =
	    unpack("i a${size} i i", $crumbs{$label});

	 if ($filename1 eq $filename2 &&
	     $ln1 == $ln2 &&
	     $off1 == $off2) {

	    delete $crumbs{$label};
	 }
      }
   }
   untie %crumbs;
   untie %badcrumbs;

   print "Unload complete.";

   show(1) if (defined($_been_here));

   return 0;
}

sub crumbDB {

   my $crumbfile = Vile::get('%breadcrumbs');

   if ($crumbfile eq 'ERROR' || $crumbfile eq '') {
      $crumbfile = $DEFAULT_DATABASE;
   }

   return $crumbfile;
}

1;

__END__

=head1 NAME

Breadcrumbs - Provides named placeholders for Vile.

=head1 SYNOPSIS

   :perl use Breadcrumbs
   :dropcrumb <label>
   :findcrumb <label>
   :eatcrumb <label>
   :loadcrumbs <file>
   :unloadcrumbs <file>
   :showcrumbs
   :breadcrumbs-help

=head1 DESCRIPTION

The Breadcrumbs package provides a named placeholder capability
for the Vile editor.  (I'm shying away from the word "bookmarks"
to avoid WWW-related confusion.)  The effect is similar to using
tags when programming, except you get to apply any label you wish
to a spot in a file.  Later you can return to a location in a file
by providing the appropriate label.

Crumbs are stored in a database file, and thus are preserved between
editor sessions.  If you try to jump to a spot in a file that isn't
loaded yet, the editor loads the needed file automagically.

Crumb labels are case sensitive.

The default crumbfile location is I<~/.vilecrumbs>.  You can customize
the location by using the B<%breadcrumbs> variable, e.g.:

   setv %breadcrumbs /tmp/mycrumbs

You can begin using a new crumbfile anytime during an
editing session by changing the value of B<%breadcrumbs>.  The
change takes effect immediately.

The effect of the Breadcrumbs' commands are atomic with respect
to the disk copy of the crumbfile.  There is no notion of "saving"
or "committing" changes.  If you delete a crumb, it's gone.
Backups are recommended.

=head1 INSTALLATION

[Note: Breadcrumbs may already be installed for you as part of your
Vile installation.]

Install Breadcrumbs.pm somewhere in perl's @INC path.  Depending on your
Vile installation, I</usr/local/share/vile/perl> might be a good place.

As currently written, Breadcrumbs requires that your system
(and your Perl) supports the Berkeley DB.  If you don't have
DB, you'll need to either get it (and maybe rebuild your Vile
with a version of Perl that supports it), or muck about with
the Breadcrumbs code so you can use DBM or whatever.

=head1 USAGE

=item :perl use Breadcrumbs

Load the Breadcrumbs package into Vile.

=item :dropcrumb <label>

Store a crumb that matches the current cursor position.

=item :findcrumb <label>

Return to a stored crumb.

=item :eatcrumb <label>

Delete a crumb from the current crumbfile.

=item :loadcrumbs <file>

Given a crumbfile path, merges all the crumbs from
that crumbfile into the current one.  If the same crumb name
appears in both crumbfiles, you will be asked whether or not
you want to overwrite the current value.

=item :unloadcrumbs <file>

Given a crumbfile path, removes any crumbs from the current
crumbfile that exist in the given crumbfile, i.e. reverses
the effect of a loadcrumbs command.

=item :showcrumbs

Brings up a buffer containing a list of all the crumbs in the current
crumbfile.  Due to certain limitations in Vile, this list buffer is not
static, i.e. it doesn't necessarily go away when you kill its window.
However, when you enter some Breadcrumbs' command that might affect its
contents, the list buffer is updated if it's visible, and destroyed if
it's not visible.  I suppose you could say it's a semi-static buffer.
The crumb list is sorted alphabetically, by default.  Sorting can be
turned off by setting the variable B<%breadcrumbs_nosort> to a non-zero
value.

=item :breadcrumbs-help

Show this manual page.

=head1 TODO

Some exercises left to the reader:

=over 4

=item *

Useful breadcrumb keybindings and macros, e.g. jump to the
label under the cursor...

=item *

Label completion for the I<findcrumb> command, to include
showing all potential matches.

=item *

Autogenerated menu of breadcrumbs for use in XVile & WinVile...

=back

=head1 BUGS

Where?!

Some oddities may occur because the crumb-list buffer is not
static.  (Vile only supports a fixed set of static buffers.)
Nothing too major though.  Just an occasional core dump perhaps...

=head1 SEE ALSO

vile(1)

=head1 CREDITS

Idea courtesy of Clemens Fischer.

=head1 AUTHOR

S<J. Chris Coppick, 2001 (last updated: Sept. 18, 2001)>

=cut
