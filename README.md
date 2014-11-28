# SCRIPT NAME

monitor-aws-status-to-slack.pl

# DESCRIPTION

monitor-aws-status-to-slack checks AWS service health dashboard periodically and notifies us a new problem by Slack.  
You can select notifications to post into Slack by AWS region and service.

# USAGE

```
# yum -y update
# cat /etc/system-release
Amazon Linux AMI release 2014.09
```

Install some library.
```
# yum -y install perl-ExtUtils-Manifest perl-ExtUtils-MakeMaker perl-CPAN-Meta perl-Module-Build perl-XML-Parser perl-XML-LibXML gcc openssl-devel git
```

Git clone.
```
# git clone https://github.com/takeshiyako2/monitor-aws-status-to-slack.git
# cd monitor-aws-status-to-slack; ls -al;
```

Install cpanm and perl modules.
```
# curl -LO http://xrl.us/cpanm
# perl cpanm --installdeps .
```

Set Slack Incoming Webhook URL.  
```
our $slack_url = 'https://hooks.slack.com/services/your/webhook/url';
```

Run script.  
```
# perl monitor-aws-status-to-slack.pl
```

# ORIGIN

hirose31  
https://github.com/hirose31/monitor-aws-status

