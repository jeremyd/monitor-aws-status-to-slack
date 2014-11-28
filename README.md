# SCRIPT NAME

monitor-aws-status-to-slack.pl

# DESCRIPTION

monitor-aws-status-to-slack checks AWS service health dashboard periodically and notifies us a new problem by Slack.  
You can select notifications to post into Slack by AWS region and service.

# USAGE

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

