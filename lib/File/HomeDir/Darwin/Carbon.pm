#line 1 "File/HomeDir/Darwin/Carbon.pm"
package File::HomeDir::Darwin::Carbon;

# Basic implementation for the Dawin family of operating systems.
# This includes (most prominently) Mac OS X.

use 5.00503;
use strict;
use Cwd                   ();
use Carp                  ();
use File::HomeDir::Darwin ();

use vars qw{$VERSION @ISA};
BEGIN {
	$VERSION = '1.00';

	# This is only a child class of the pure Perl darwin
	# class so that we can do homedir detection of all three
	# drivers at one via ->isa.
	@ISA = 'File::HomeDir::Darwin';

	# Load early if in a forking environment and we have
	# prefork, or at run-time if not.
	local $@;
	eval "use prefork 'Mac::Files'";
}





#####################################################################
# Current User Methods

sub my_home {
	my $class = shift;

	# A lot of unix people and unix-derived tools rely on
	# the ability to overload HOME. We will support it too
	# so that they can replace raw HOME calls with File::HomeDir.
	if ( exists $ENV{HOME} and defined $ENV{HOME} ) {
		return $ENV{HOME};
	}

	require Mac::Files;
	$class->_find_folder(
		Mac::Files::kCurrentUserFolderType(),
	);
}

sub my_desktop {
	my $class = shift;

	require Mac::Files;
	$class->_find_folder(
		Mac::Files::kDesktopFolderType(),
	);
}

sub my_documents {
	my $class = shift;

	require Mac::Files;
	$class->_find_folder(
		Mac::Files::kDocumentsFolderType(),
	);
}

sub my_data {
	my $class = shift;

	require Mac::Files;
	$class->_find_folder(
		Mac::Files::kApplicationSupportFolderType(),
	);
}

sub my_music {
	my $class = shift;

	require Mac::Files;
	$class->_find_folder(
		Mac::Files::kMusicDocumentsFolderType(),
	);
}

sub my_pictures {
	my $class = shift;

	require Mac::Files;
	$class->_find_folder(
		Mac::Files::kPictureDocumentsFolderType(),
	);
}

sub my_videos {
	my $class = shift;

	require Mac::Files;
	$class->_find_folder(
		Mac::Files::kMovieDocumentsFolderType(),
	);
}

sub _find_folder {
	my $class = shift;
	my $name  = shift;

	require Mac::Files;
	my $folder = Mac::Files::FindFolder(
		Mac::Files::kUserDomain(),
		$name,
	);
	return undef unless defined $folder;

	unless ( -d $folder ) {
		# Make sure that symlinks resolve to directories.
		return undef unless -l $folder;
		my $dir = readlink $folder or return;
		return undef unless -d $dir;
	}

	return Cwd::abs_path($folder);
}





#####################################################################
# Arbitrary User Methods

sub users_home {
	my $class = shift;
	my $home  = $class->SUPER::users_home(@_);
	return defined $home ? Cwd::abs_path($home) : undef;
}

# in theory this can be done, but for now, let's cheat, since the
# rest is Hard
sub users_desktop {
	my ($class, $name) = @_;
	return undef if $name eq 'root';
	$class->_to_user( $class->my_desktop, $name );
}

sub users_documents {
	my ($class, $name) = @_;
	return undef if $name eq 'root';
	$class->_to_user( $class->my_documents, $name );
}

sub users_data {
	my ($class, $name) = @_;
	$class->_to_user( $class->my_data, $name )
	||
	$class->users_home($name);
}

# cheap hack ... not entirely reliable, perhaps, but ... c'est la vie, since
# there's really no other good way to do it at this time, that i know of -- pudge
sub _to_user {
	my ($class, $path, $name) = @_;
	my $my_home    = $class->my_home;
	my $users_home = $class->users_home($name);
	defined $users_home or return undef;
	$path =~ s/^\Q$my_home/$users_home/;
	return $path;
}

1;

#line 211