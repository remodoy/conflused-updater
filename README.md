Atlassian-updater
=================

Shell scripts to backup and update Atlassian products. Currently JIRA and
Confluence supported.

JIRA
====

* Copy jira/config.sh.sample to jira.config
* Edit jira.config to match your setup
* Create current symlink to JIRA_PATH if not already set
   * Fix init scripts also
* Run jira/update_jira.sh jira.config as root or normal user
* Done

Confluence
==========

* Copy confluence/config.sh.sample to confluence.config
* Edit confluence.config to match your setup
* Create current symlink to CONFLUENCE_BASE if not already set
   * Fix init scripts also
* Run confluence/update_confluence.sh confluence.config as root or normal user
* Done

License
=======

MIT license

Copyright (c) 2016 Antti Jaakkola Remod Oy

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.