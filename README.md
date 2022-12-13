# trivial-mailserver-monitor

## Simple mail server monitoring loop

Tested on SBCL on Debian.

Assumptions: you have 3 e-mail accounts:
 the robot (used to monitor) and the destination mail server mailbox
 (mail server to be monitored).
 The destination mail server mailbox is configured as a forwarder and
 returns all incoming e-mail to the robot mail account.

  A third e-mail account is your personal notification e-mail address
  if the monitoring fails. 

 Every x (e.g. 15) minutes, the program uses the robot mail account to send
  and e-mail with a hash value to the destination mail server mailbox.
 A monitoring success is defined as a returned e-mail within 10 minutes.
 A monitoring failure is defined as a situation where the mail with the hash 
 is not returned within that time. 
 The interpreation is that the destination mail server is in a state
 where it has not received the mail and/or not sent back the monitoring mail.
 In case of a monitoring failure, the admin is notified.

 e-Mail sending is performed in Lisp through cl-smtp.
 e-Mail receiving via Pop3 is facilitated via mpop.
  mpop must be configured in a way to save e-mails to ~/mpop-in/new 
