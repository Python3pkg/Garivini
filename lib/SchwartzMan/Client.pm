package SchwartzMan::Client;

use strict;
use warnings;
use fields ('dbd',
            );

use SchwartzMan::DB;

# Extremely simple shim client:
# Takes list of databases
# Takes serialized argument (or optional serialization command?)

sub new {
    my SchwartzMan::Client $self = shift;
    $self = fields::new($self) unless ref $self;
    my %args = @_;

    $self->{dbd} = SchwartzMan::DB->new(%args);

    return $self;
}

# Very bland DBI call.
# dbid => send to a specific DB (remove this? seems dangerous)
# job  => { funcname => $name,
#           run_after => $timestamp, (optional, defaults to UNIX_TIMESTAMP())
#           unique => $unique, (string)
#           coalesce => $key, (coalesce key, like the e-mail domain)
#           arg => $blob, (serialized blob)
#         };
# TODO: Is there value in returning the jobid? If so, adding it won't be hard.
sub insert_job {
    my $self = shift;
    my %args = @_;
    $args{unique}    = undef unless $args{unique};
    $args{coalesce}  = undef unless $args{coalesce};
    # FIXME: Verify $run_after as an argument, or else we have an injection
    # issue.
    my $run_after = 'UNIX_TIMESTAMP()' unless $args{run_after};
    my ($ret, $dbh, $dbid) = $self->{dbd}->do(undef,
        "INSERT INTO job (funcname, run_after, uniqkey, coalesce, arg) "
        . "VALUES (?, $run_after, ?, ?, ?)", undef,
        @args{'funcname', 'unique', 'coalesce', 'arg'});
    return $dbh->last_insert_id(undef, undef, undef, undef);
}

# Just in case?
sub cancel_job {
    my $self  = shift;
}

# Further potential admin commands:
sub list_jobs {

}

# Pull jobs scheduled for ENDOFTIME
sub failed_jobs {

}

# On job complete or failure, call one of these:

# Takes a job handle, issues a DELETE against the database directly.
sub complete_job {
    my $self = shift;
    my $job  = shift;

    # Job should have the dbid buried in the reference.
    my $dbid = $job->{dbid}
        or die "Malformed job missing dbid argument";
    my $jobid = $job->{jobid}
        or die "Malformed job missing id argument";
    $self->{dbd}->do($dbid, "DELETE FROM job WHERE jobid=?", undef, $jobid);
}

# Bump the run_after in some specific way (relative, absolute, etc)
sub reschedule_job {

}

# Reschedule for ENDOFTIME
sub fail_job_permanently {

}

1;
