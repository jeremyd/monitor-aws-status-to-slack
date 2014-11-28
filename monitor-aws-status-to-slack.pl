#!/usr/bin/env perl

=head1 SCRIPT NAME

monitor-aws-status-to-slack.pl

=head1 DESCRIPTION

monitor-aws-status checks AWS service health dashboard periodically and notifies us a new problem by Slack.
You can select notifications to post into Slack by AWS region and service.

=head1 USAGE

Set Slack Incoming Webhook URL. 
our $slack_url = 'https://hooks.slack.com/services/your/webhook/url';

Run script. 
perl monitor-aws-status-to-slack.pl

=head1 ORIGIN

hirose31
https://github.com/hirose31/monitor-aws-status

=cut

use strict;
use warnings;
use utf8;

use Getopt::Long qw(:config posix_default no_ignore_case no_ignore_case_always);
use Smart::Args;
use Log::Minimal;
use Carp;

use AnyEvent;
use AnyEvent::Feed;
use AnyEvent::HTTP;
use Furl;

# Set the required variables.
our $slack_url = 'https://hooks.slack.com/services/your/webhook/url';
our $slack_channel = '#random';
our $slack_username = 'monitor-aws-status';
our $slack_icon_emoji = ':cloud:';

our %Target_Region = (
    "eu-west-1"      => "EU (Ireland)",
    "sa-east-1"      => "South America (Sao Paulo)",
    "us-east-1"      => "US East (Northern Virginia)",
    "ap-northeast-1" => "Asia Pacific (Tokyo)",
    "us-west-2"      => "US West (Oregon)",
    "us-west-1"      => "US West (Northern California)",
    "ap-southeast-1" => "Asia Pacific (Singapore)",
    "ap-southeast-2" => "Asia Pacific (Sydney)",
    );

our $BOOT_TIME = time;
our $Debug    = 0;
our $Interval = 300;

our %Ignore_Service = map {$_=>1} qw(fps);

our $_UA;
sub ua() {
    $_UA ||= Furl->new( timeout => 5 );
    return $_UA;
}

MAIN: {
    my %arg;
    GetOptions(
        \%arg,
        'interval|i=i',
        'debug|d+' => \$Debug,
        'help|h|?' => sub { die "usage" }) or die "usage";
    $ENV{LM_DEBUG} = 1 if $Debug;

    $Interval = $arg{interval} if exists $arg{interval};

    my $target_feeds = load_config();
    my @feed_readers;

    for my $target (@{ $target_feeds }) {
        push @feed_readers,
            AnyEvent::Feed->new (
                url      => $target->{url},
                interval => $Interval,

                on_fetch => sub {
                    my ($feed_reader, $new_entries, $feed, $error) = @_;
                    debugf("on fetch: $target->{url}");

                    if (defined $error) {
                        critf("ERROR: %s", $error);
                        return;
                    }

                    $target->{process}->($new_entries, $target->{opt});
                }
            );
    }

    AE::cv->recv;

    exit 0;
}

sub load_config {
    return [
        {
            name    => 'aws-status',
            url     => 'http://status.aws.amazon.com/rss/all.rss',
            process => \&process_aws_status,
            opt => {
                channel => $slack_channel, # change as you like
            },
        },
    ];
}

sub post_slack {
    args(
        my $channel  => { isa => 'Str' },
	my $messages => { isa => 'ArrayRef[Str]' },
	);

    for my $message (@$messages) {
        debugf("POST to %s, %s", $channel, $message);

	utf8::encode($message);

        ua->post(
            "${slack_url}",
            [],
            [
	        payload => "{\"channel\":\"$channel\",\"username\":\"$slack_username\",\"text\":\"$message\",\"icon_emoji\":\"$slack_icon_emoji\",\"parse\":\"default\"}",
            ],
	    );
    }

}

sub process_aws_status {
    my($entries, $opt) = @_;

    for (@$entries) {
        # entry is XML::Feed::Entry object
        my ($hash, $entry) = @$_;

        # skip old entries
        if ($entry->issued->epoch < $BOOT_TIME) {
            infof("skip %s, because issued < BOOT_TIME (%d < %d)",
                  $entry->title,
                  $entry->issued->epoch,
                  $BOOT_TIME,
              );
            next if $Debug == 0;
        }

        my $title = $entry->title;
        my $description = $entry->content->body;
        $description =~ s/[\r\n]/ /g;

        my($sv_reg) = $entry->id =~ /#(.+)$/; # <guid>
        $sv_reg =~ s/_[0-9]+$//;
        my($service, $region) = split /-/, $sv_reg, 2;
        $region ||= 'ALL';

        # issued is DateTime object
        my $dt = $entry->issued;
        # convert to JST
        $dt->set_time_zone('Asia/Tokyo');

        my $status = $title =~ /resolved/i ? 'RECOVER' : 'PROBLEM';
        my $status_color = $status eq 'RECOVER' ? 'green' : 'red';

        infof("[%s] %s on %s at %s (%s)\n  %s\n  %s\n\n",
               $status,
               $service, $region, $dt->iso8601, $dt->time_zone_short_name,
               $title,
               $description,
           );

        if (!$Target_Region{ $region } && $region ne 'ALL') {
            next;
        }
        if (exists $Ignore_Service{$service}) {
            next;
        }

        my @messages;
        push @messages, sprintf("%s [%s] on %s, %s at %s (%s)", 
                                $status, 
                                $service, 
                                $region, 
                                $title, 
                                $dt->iso8601, 
                                $dt->time_zone_short_name,
                            );
        push @messages, sprintf("%s, <%s>",
                                $description,
                                $entry->link,
                            );

        post_slack(
            channel  => $opt->{channel},
            messages => \@messages,
        );

    }
}

__END__

