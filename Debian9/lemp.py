#!/usr/bin/env python3
# Copyright 2017 Matteo Mattei <info@matteomattei.com>

import sys
import os
import shutil
import subprocess
from tld import get_tld

######### CONFIGURATION ############
BASE_ROOT='/home'
START_USER_NUM=5001
BASE_USER_NAME='web'
PHP_FPM_TEMPLATE='/etc/php/7.0/fpm/pool.d/www.conf'

####################################
############ FUNCTIONS #############
######### Do not edit below ########

def usage():
    """This function simply returns the usage"""
    sys.stdout.write('Usage: %s [add|delete] domain.tld\n' % sys.argv[0])

def valid_domain(domain):
    """This function return True if the passed domain is valid, false otherwise"""
    try:
        get_tld(domain,fix_protocol=True)
        return True
    except:
        return False

def tld_and_sub(domain):
    """This function returns a dictionary with tld (top level domain) and
    the related subdomain, www in case no subdomain is passed"""
    tld = get_tld(domain,fix_protocol=True)
    if domain==tld:
        return {'tld':domain,'name':'www'}
    index = domain.find(tld)
    return {'tld':tld,'name':domain[0:(index-1)]}

def get_next_user():
    """This function returns a dictionary with the next available username and its uid"""
    buf = []
    with open('/etc/passwd','r') as f:
        buf = f.readlines()
    idx = str(START_USER_NUM)
    while True:
        user = BASE_USER_NAME+idx+':'
        found = False
        for line in buf:
            if line.startswith(user):
                found = True
                break
        if found == True:
            idx = str(int(idx)+1)
        else:
            return {'username':user.strip(':'),'uid':int(idx)}

def add_new_user(username,uid,homedir):
    """This function adds a new system user with specified parameters"""
    res = subprocess.run([
        'useradd',
        '--comment="WEB_USER_'+str(uid)+',,,"',
        '--home-dir='+homedir,
        '--no-log-init',
        '--create-home',
        '--shell=/bin/bash',
        '--uid='+str(uid),
        username], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.stderr != b'':
        sys.stdout.write('Error adding user %s with uid %d: %s\n' % (username,uid,res.stderr))
        sys.exit(1)

def remove_user(homedir):
    """This function removes the user which domain belongs to"""
    buf = []
    with open('/etc/passwd','r') as f:
        buf = f.readlines()
    username = ''
    for line in buf:
        if ':'+homedir+':' in line:
            username = line.split(':')[0]
            break
    if username != '':
        res = subprocess.run([
            'userdel',
            username], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if res.stderr != b'':
            sys.stdout.write('Error removing user %s: %s\n' % (username,res.stderr))
            sys.exit(1)

def remove_domain_folder(homedir):
    """This function removes the home directory of the domain"""
    if os.path.isdir(homedir):
        res = subprocess.run([
            'rm',
            '-rf',
            homedir], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if res.stderr != b'':
            sys.stdout.write('Error removing domain folder %s\n' % homedir)
            sys.exit(1)

def lock_password(username):
    """This function lock the password for the user"""
    res = subprocess.run([
        'passwd',
        '-l',
        username], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.stderr != b'':
        sys.stdout.write('Error locking password to user %s: %s\n' % (username,res.stderr))
        sys.exit(1)

def create_subfolders(username,homedir):
    """This function creates subfolders of domain directory"""
    dirname = os.path.join(homedir,'public_html')
    if not os.path.isdir(dirname):
        os.mkdir(dirname)
        shutil.chown(dirname,username,username)
    dirname = os.path.join(homedir,'tmp')
    if not os.path.isdir(dirname):
        os.mkdir(dirname)
        shutil.chown(dirname,username,username)
    dirname = os.path.join(homedir,'logs')
    if not os.path.isdir(dirname):
        os.mkdir(dirname)
        shutil.chown(dirname,'root','root')

def create_php_pool(username, domain, homedir):
    """This function creates a php pool configuration file"""
    if not os.path.isfile(PHP_FPM_TEMPLATE):
        sys.stdout.write('No php fpm template found (%s)!\n' % PHP_FPM_TEMPLATE)
        sys.exit(1)
    filename = os.path.join('/etc/php/7.0/fpm/pool.d/',domain+'.conf')
    if os.path.isfile(filename):
        sys.stdout.write('PHP configuration file already exists: %s\n' % filename)
        sys.exit(1)
    lines = [] 
    with open(PHP_FPM_TEMPLATE,'r') as f:
        lines = f.readlines()
    with open(filename,'w') as f:
        for l in lines:
            if l.startswith('user = www-data'):
                f.write(l.replace('www-data',username))
                continue
            if l.startswith('group = www-data'):
                f.write(l.replace('www-data',username))
                continue
            if l.startswith('[www]'):
                f.write(l.replace('www',domain))
                continue
            if l.startswith('listen = '):
                f.write('listen = /var/run/php/php7.0-fpm_'+domain+'.sock\n')
                continue
            if l.startswith(';env[TMP]'):
                f.write('env[TMP] = '+os.path.join(homedir,'tmp')+'\n')
                continue
            if l.startswith(';env[TMPDIR]'):
                f.write('env[TMPDIR] = '+os.path.join(homedir,'tmp')+'\n')
                continue
            if l.startswith(';env[TEMP]'):
                f.write('env[TEMP] = '+os.path.join(homedir,'tmp')+'\n')
                continue
            f.write(l)

def remove_php_pool(domain):
    """This function removes the php pool of the domain"""
    filename = '/etc/php/7.0/fpm/pool.d/'+domain+'.conf'
    if os.path.isfile(filename):
        os.unlink(filename)

def get_ssl_certs(domain):
    """This function use certbot to obtain the SSL certificates for the domain"""
    res = subprocess.run([
        'certbot',
        'certonly',
        '--webroot',
        '--webroot-path',
        '/var/www/html',
        '-d',
        domain], stdout=subprocess.PIPE, stderr=subprocess.PIPE);
    if res == b'':
        sys.stdout.write('Unable to obtain SSL certificates for domain %s: %s\n' % (domain, res.stderr))
        sys.exit(1)
    if not os.path.islink('/etc/letsencrypt/live/'+domain+'/fullchain.pem'):
        sys.stdout.write('Missing SSL certificate %s\n','/etc/letsencrypt/live/'+domain+'/fullchain.pem')
        sys.exit(1)

def remove_ssl_certs(domain):
    """This function removes all SSL certificates of a domain"""
    if os.path.isdir('/etc/letsencrypt/live/'+domain):
        shutil.rmtree('/etc/letsencrypt/live/'+domain)
    if os.path.isdir('/etc/letsencrypt/archive/'+domain):
        shutil.rmtree('/etc/letsencrypt/archive/'+domain)
    if os.path.isfile('/etc/letsencrypt/renewal/'+domain+'.conf'):
        os.unlink('/etc/letsencrypt/renewal/'+domain+'.conf')

def create_nginx_virtualhost(domain,homedir):
    """This function creates the NGINX virtualhost"""
    filename = '/etc/nginx/sites-available/'+domain
    dst_filename = '/etc/nginx/sites-enabled/'+domain
    if os.path.isfile(filename):
        sys.stdout.write('Virtualhost configuration already exists: %s\n' % filename)
        sys.exit(1)
    domain_parts = tld_and_sub(domain)
    with open(filename,'w') as f:
        f.write('server {\n')
        f.write('    listen 80;\n')
        if domain_parts['name'] == 'www':
            f.write('    server_name '+domain_parts['tld']+' '+domain_parts['name']+'.'+domain_parts['tld']+';\n');
        else:
            f.write('    server_name '+domain_parts['name']+'.'+domain_parts['tld']+';\n')
        f.write('    return 301 https://'+domain_parts['name']+'.'+domain_parts['tld']+'$request_uri;\n')
        f.write('}\n')
        f.write('server {\n')
        f.write('    server_name '+domain_parts['name']+'.'+domain_parts['tld']+';\n')
        f.write('    listen 443 ssl http2;\n')
        f.write('    access_log '+os.path.join(homedir,'logs','nginx.access.log')+';\n')
        f.write('    error_log '+os.path.join(homedir,'logs','nginx.error.log')+';\n')
        f.write('    root '+os.path.join(homedir,'public_html')+';\n')
        f.write('    set $php_sock_name '+domain_parts['name']+'.'+domain_parts['tld']+';\n')
        f.write('    include /etc/nginx/global/common.conf;\n')
        f.write('    include /etc/nginx/global/wordpress.conf;\n')
        f.write('    ssl_certificate /etc/letsencrypt/live/'+domain_parts['name']+'.'+domain_parts['tld']+'/fullchain.pem;\n')
        f.write('    ssl_certificate_key /etc/letsencrypt/live/'+domain_parts['name']+'.'+domain_parts['tld']+'/privkey.pem;\n')
        f.write('    include /etc/nginx/global/ssl.conf;\n')
        f.write('}\n')
    os.symlink(filename,dst_filename)

def remove_nginx_virtualhost(domain):
    """This function removes nginx virtualhost of a domain"""
    if os.path.islink('/etc/nginx/sites-enabled/'+domain):
        os.unlink('/etc/nginx/sites-enabled/'+domain)
    if os.path.isfile('/etc/nginx/sites-available/'+domain):
        os.unlink('/etc/nginx/sites-available/'+domain)

def reload_services():
    """This function reloads configurations of PHP-FPM and NGINX services"""
    res = subprocess.run([
        '/etc/init.d/php7.0-fpm',
        'reload'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.stderr != b'':
        sys.stdout('Unable to reload PHP: %s\n' % res.stderr)
        sys.exit(1)
    res = subprocess.run([
        '/etc/init.d/nginx',
        'reload'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.stderr != b'':
        sys.stdout('Unable to reload NGINX: %s\n' % res.stderr)
        sys.exit(1)

####################################
######### MAIN STARTS HERE #########
if os.getuid() != 0:
    sys.stdout.write('This program must be executed as root')
    sys.exit(1)

if len(sys.argv)<3:
    usage()
    sys.exit(1)

# check domain validity
action = sys.argv[1]
if action not in ('add','delete'):
    sys.stdout.write('Invalid action %s\n' % action)
    sys.exit(1)

domain = sys.argv[2]
if valid_domain(domain)==False:
    sys.stdout.write('Invalid domain %s\n' % domain)
    sys.exit(1)

if action == 'add':
    # check if domain already exists
    domain_parts = tld_and_sub(domain)
    base_domain_dir = os.path.join(BASE_ROOT,domain_parts['tld'])
    child_domain_dir = os.path.join(base_domain_dir,domain_parts['name']+'.'+domain_parts['tld'])
    domain = domain_parts['name']+'.'+domain_parts['tld']
    if os.path.isdir(child_domain_dir):
        sys.stdout.write('Domain %s already exists at %s\n' % (domain,child_domain_dir))
        sys.exit(1)

    # add new user
    if not os.path.isdir(base_domain_dir):
        os.mkdir(base_domain_dir)
    user = get_next_user()
    add_new_user(user['username'],user['uid'],child_domain_dir)

    # lock user password
    lock_password(user['username'])

    # create additional folders
    create_subfolders(user['username'],child_domain_dir)

    # create PHP pool
    create_php_pool(user['username'],domain,child_domain_dir)

    # obtain SSL certificates from letsencrypt
    get_ssl_certs(domain)

    # create NGINX virtualhost
    create_nginx_virtualhost(domain,child_domain_dir)

    # reload services (nginx + php-fpm)
    reload_services()

if action == 'delete':
    # check if domain already exists
    domain_parts = tld_and_sub(domain)
    base_domain_dir = os.path.join(BASE_ROOT,domain_parts['tld'])
    child_domain_dir = os.path.join(base_domain_dir,domain_parts['name']+'.'+domain_parts['tld'])
    domain = domain_parts['name']+'.'+domain_parts['tld']
    if not os.path.isdir(child_domain_dir):
        sys.stdout.write('Domain %s does not exist at %s\n' % (domain,child_domain_dir))
        sys.exit(1)
    
    # remove user if present
    remove_user(child_domain_dir)

    # remove domain folder
    remove_domain_folder(child_domain_dir)

    # remove php pool
    remove_php_pool(domain)

    # remove ssl certificates
    remove_ssl_certs(domain)

    # remove nginx virtualhost
    remove_nginx_virtualhost(domain)

    # reload services (nginx + php-fpm)
    reload_services()
