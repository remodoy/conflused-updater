#!/usr/bin/env python

"""
Java version updater

Copyright 2018 Remod Oy

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

"""

from tempfile import mkstemp
import os
import os.path
import tarfile
try:
    # Python2
    from urllib2 import urlopen
    from urllib2 import Request
except ImportError:
    # Python3
    from urllib.request import urlopen
    from urllib.request import Request
import re


def get(url, headers={}):
    request = Request(url, headers=headers)
    res = urlopen(request)
    content = res.read()
    res.close()
    return content


def get_java():
    res = get("http://www.oracle.com/technetwork/java/javase/downloads/index.html")
    download_page_m = re.compile('.*"(/technetwork/java/javase/downloads/server-jre8-downloads-.*.html)".*')
    next_url = None
    for line in res.splitlines():
        match = download_page_m.match(line)
        if match:
            next_url = "http://www.oracle.com%s" % match.group(1)
            print(next_url)
            break
    if not next_url:
        print("Failed to get download page url")
        return None
    res = get(next_url)
    download_pkg_m = re.compile('.*filepath":"(.*server-jre-(.*)-linux-x64.tar.gz)".*')
    for line in res.splitlines():
        match = download_pkg_m.match(line)
        if match:
            next_url = match.group(1)
    if not next_url:
        print("Failed to get package download url")
        return None
    print("Downloading %s" % next_url)
    tempfile, tempfile_path = mkstemp(suffix='.tar.gz')
    res = get(next_url, headers={"Cookie": "oraclelicense=accept-securebackup-cookie"})
    os.write(tempfile, res)
    os.close(tempfile)

    return tempfile_path


def install_java(tarpath, installpath):
    os.umask(0o022)
    if not os.path.isdir(installpath):
        os.mkdir(installpath, 0o755)
    tar = tarfile.open(tarpath, "r:gz")
    tar.extractall(installpath)
    java_name = tar.getnames()[0]
    if os.path.islink(os.path.join(installpath, 'current')):
        os.remove(os.path.join(installpath, 'current'))
    os.symlink(os.path.join(installpath, java_name), os.path.join(installpath, 'current'))


if __name__ == '__main__':
    java_tar = get_java()
    if java_tar:
        print(java_tar)
        install_java(java_tar, '/opt/java')
    os.remove(java_tar)
