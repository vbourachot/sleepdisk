# sleepdisk
Shell script to puts specified drive(s) in standby when no read/write activity occurs over a configurable period of time. Relies on hdparm to do the actual work.
My goal was to do this as simply as possible (25 lines or less) while supporting md arrays.
A couple of systemd unit files are included as samples.
