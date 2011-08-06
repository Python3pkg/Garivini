package SchwartzMan::Controller;

use strict;
use warnings;
use fields ('dbd',
            'sm_client',
            'gm_client',
           );

use SchwartzMan::DB;
use SchwartzMan::Client;
use Gearman::Client;
use Gearman::Worker;
use JSON;

use constant DEBUG => 1;

sub new {
    my SchwartzMan::Controller $self = shift;
    $self = fields::new($self) unless ref $self;
    my %args = @_;

    $self->{job_servers} = delete $args{job_servers};
    $self->{sm_client} = SchwartzMan::Client->new(%args);
    $self->{gm_client} = Gearman::Client->new(
        job_servers => $self->{job_servers});

    return $self;
}

sub work {
    my $worker = Gearman::Worker->new(job_servers => $self->{job_servers});
    $worker->register_function('run_queued_job' => sub {
        $self->run_queued_job;
    });
    $worker->work while 1; # redundant.
}

sub run_queued_job {
    my $self = shift;
    my $gm_job  = shift;

    my $sm_client = $self->{sm_client};
    my $gm_client = $self->{gm_client};

    my $sm_job = decode_json(${$gm_job->argref});
    DEBUG && warn "Got a job $sm_job->{funcname}\n";

    # NOTE: This passes the full job around, instead of initially passing a
    # handle and SELECT'ing it back from the DB here. Need to ensure this is
    # worth the tradeoff.
    my $res = $gm_client->do_task($sm_job->{funcname}, $gm_job->argref);
    DEBUG && warn "Gearman do_task result is $res\n";

    if (defined $res) {
        $sm_client->complete_job($sm_job);
    } else {
        # TODO: Be more intelligent about when a failure requires a retry, vs
        # when it's permanently dead?
        $sm_client->reschedule_job($sm_job);
    }
}

1;