=encoding utf8

=head1 caution

	This perldoc can see in the "perldoc -t " command.

=head1 ���O

Session - �Z�b�V�������ʏ���

=head1 �T�v
	
	���O�C����񓙂̃Z�b�V�����Ǘ����s��

=head1 �g�p���@

	use Session;
	$obj = new Session();
	$session_id = $obj->make_session();
	exit;
	

=back

=head1 ���쌠

Copyright 2014 Unago tentatsu.

This software is released under the MIT License

=cut

package Session;

use Data::Dumper;

use CGI;
use DB_File;
use DBM_Filter;
use Digest::MD5 qw(md5_hex);

sub new {
	my $class = shift;
	my $self = {@_};
	$self->{session_id} = $class->get_session_id();
	$self->{session_obj} = "";
	return bless $self, $class;
}

sub get_session_id {
	my $self = shift;
	my $q = CGI->new();
	return $self->{session_id} if ($self->{session_id});
	return $q->cookie($main::SESSION_ID) || "";
}

sub set_session {
	my $self = shift;
	my ($target, $data) = @_;
	my $session_file = $main::SESSION_DIR. "/". $self->get_session_id();
	#�Z�b�V�����f�[�^�t�@�C�����J�� (�������͍쐬) 
	tie( %sessionvals, 'DB_File', $session_file, O_RDWR , 0600, $DB_HASH )
		or &fatal_error( "Tieing $session_file", $! );
	$sessionvals{$target} = $data;
	return;
}	
#sub get_role {
#	my $self = shift;
#	return 0 unless($self->{session_obj});
#	
#}

sub get_session_data {
	my $self = shift;
	my $target = shift if (@_);
	my $session_file = $main::SESSION_DIR. "/". $self->get_session_id();
	
	#�Z�b�V�����f�[�^�t�@�C�����J�� (�������͍쐬) 
	tie( %sessionvals, 'DB_File', $session_file, O_RDWR , 0600, $DB_HASH )
		or &fatal_error( "Tieing $session_file", $! );
	
	
	return $sessionvals{$target} if(exists($sessionvals{$main::SESSION_FILE_ROLE}));
	return undef;
}


sub make_session {
	my $self = shift;
	my $role = shift if (@_);
	my %sessionvals;
	
	my $session_id = md5_hex( time ^ $$ ^ unpack '%32L*', $ENV{REMOTE_ADDR} . ( $ENV{HTTP_USER_AGENT} || '' ) );
	my $session_file = $main::SESSION_DIR. "/$session_id";

	#�V�����Z�b�V����ID����������́A���̖��O�̊����Z�b�V�����f�[�^�t�@�C���͖��������m�F
	my $try = 4; #4�񎎂�
	while ( --$try && -f $session_file ) {
		sleep(5);
		$session_id = md5_hex( time ^ $$ ^ unpack '%32L*', $ENV{REMOTE_ADDR} . ( $ENV{HTTP_USER_AGENT} || '' ) );
		$session_file = $main::SESSION_DIR. "/$session_id";
	}
	-f $session_file
	    and &fatal_error( "�Z�b�V�����f�[�^�����ɑ��݂��܂��B" );
	
	#�Z�b�V�����f�[�^�t�@�C�����J�� (�������͍쐬) 
	$self->{session_id} = $session_id;
	tie( %sessionvals, 'DB_File', $session_file, O_RDWR | O_CREAT, 0600, $DB_HASH )
		or &fatal_error( "Tieing $session_file", $! );
	if ($role) {
		$self->set_session($main::SESSION_FILE_ROLE, $role);
	}
	untie %sessionvals;

	#�����Â��Z�b�V�����f�[�^���c���Ă��܂��Ă�����폜����
	my ($dh);
	opendir( $dh, $main::SESSION_DIR )
		or &fatal_error( "Opening $main::SESSION_DIR", $! );
	my @failed =
		grep { !unlink $_ }
		map { m/$main::SESSION_FILE_REG/ and $main::SESSION_DIR. "/$1" }
		grep { m/$main::SESSION_FILE_REG/ 
		    and -f $main::SESSION_DIR. "/$_" 
		    and ( stat($main::SESSION_DIR. "/$_") )[9] < time - $main::SESSION_FILE_DURATION * 60 * 60 
		}
		readdir($dh)
	;

	closedir($dh);
	scalar @failed
		and &fatal_error( sprintf( 'Deleteing %s', join( ',', @failed ) ), $! );
	
	return $session_id;
	
}
sub vd {
	my $self = shift;
	print "Content-Type: text/html\n\n";
	print Dumper @_;
	exit;
}

1; 
