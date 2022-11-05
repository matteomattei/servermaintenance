#!/usr/bin/env python3
# LEMP MANAGER v1.2
# Copyright 2017-2022 Matteo Mattei <info@matteomattei.com>

import sys
import os
import shutil
import subprocess
import getopt
import crypt
import pwd
from tld import get_fld

######### CONFIGURATION ############
BASE_ROOT='/home'
START_USER_NUM=5001
BASE_USER_NAME='web'
PHP_FPM_TEMPLATE='/etc/php/7.4/fpm/pool.d/www.conf'
USER_PASSWORD='qwertyuioplkjhgfdsazxcvbnm'

####################################
############ FUNCTIONS #############
######### Do not edit below ########

def usage():
    """This function simply returns the usage"""
    sys.stdout.write('Usage:\n')
    sys.stdout.write('%s -a|--action=<action> [-d|--domain=<domain>] [-A|--alias=<alias>] [options]\n' % sys.argv[0])
    sys.stdout.write('\nParameters:\n')
    sys.stdout.write('\t-a|--action=ACTION\n\t\tit is mandatory\n')
    sys.stdout.write('\t-d|--domain=domain.tld\n\t\tcan be used only with [add_domain, remove_domain, add_alias, get_certs, get_info]\n')
    sys.stdout.write('\t-A|--alias=alias.domain.tld\n\t\tcan be used only with [add_alias, remove_alias, get_info]\n')
    sys.stdout.write('\nActions:\n')
    sys.stdout.write('\tadd_domain\tAdd a new domain\n')
    sys.stdout.write('\tadd_alias\tAdd a new domain alias to an existent domain\n')
    sys.stdout.write('\tremove_domain\tRemove an existent domain\n')
    sys.stdout.write('\tremove_alias\tRemove an existent domain alias\n')
    sys.stdout.write('\tget_certs\tObtain SSL certificate and deploy it\n')
    sys.stdout.write('\tget_info\tGet information of a domain or a domain alias (username)\n')
    sys.stdout.write('\nOptions:\n')
    sys.stdout.write('\t-f|--fakessl\tUse self signed certificate (only usable with [add_domain, add_alias])\n')

def valid_domain(domain):
    """This function return True if the passed domain is valid, false otherwise"""
    try:
        get_fld(domain,fix_protocol=True)
        return True
    except:
        return False

def tld_and_sub(domain):
    """This function returns a dictionary with tld (top level domain) and
    the related subdomain, www in case no subdomain is passed"""
    tld = get_fld(domain,fix_protocol=True)
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
    enc_password = crypt.crypt(USER_PASSWORD,crypt.mksalt(crypt.METHOD_SHA512))
    res = subprocess.run([
        'usermod',
        '-p',
        enc_password,
        username], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.stderr != b'':
        sys.stdout.write('Error setting password for user %s: %s\n' % (username,res.stderr))
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
    filename = os.path.join('/etc/php/7.4/fpm/pool.d/',domain+'.conf')
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
                f.write('listen = /var/run/php/php7.4-fpm_'+domain+'.sock\n')
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
    filename = '/etc/php/7.4/fpm/pool.d/'+domain+'.conf'
    if os.path.isfile(filename):
        os.unlink(filename)

def domains_in_virtualhost(domain):
    """This function returns the list of domains configured in the virtualhost"""
    buf = []
    with open('/etc/nginx/sites-available/'+domain,'r') as f:
        buf = f.readlines()
    domains = []
    for line in buf:
        if '    server_name ' in line:
            domains = line.strip().strip(';').split()[1:]
            break
    return domains

def check_update_ssl_certs(domains):
    """This function get ssl certificates for all domains in virtualhost and adjust it"""
    if len(domains)==0:
        sys.stdout.write('No domain provided to certbot!\n')
        return
    domains_list = []
    for d in domains:
        domains_list.append('-d')
        domains_list.append(d.strip())

    res = subprocess.run([
        'certbot',
        'certonly',
        '--keep-until-expiring',
        '--expand',
        '--webroot',
        '--webroot-path',
        '/var/www/html']+domains_list, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if not os.path.islink('/etc/letsencrypt/live/'+domains[0].strip()+'/fullchain.pem'):
        sys.stdout.write('Missing SSL certificate %s\n' % '/etc/letsencrypt/live/'+domains[0].strip()+'/fullchain.pem')
        sys.stdout.write('Look at %s for more information about\n' % '/var/log/letsencrypt/letsencrypt.log')
        return
    buf = []
    with open('/etc/letsencrypt/renewal/'+domains[0].strip()+'.conf','r') as f:
        buf = f.readlines()
    for d in domains:
        for line in buf:
            if line.startswith(d.strip()+' ='):
                found = True
                break
        if not found:
            with open('/etc/letsencrypt/renewal/'+d.strip()+'.conf','a') as f:
                f.write(d.strip()+' = /var/www/html\n')
    domain_parts = tld_and_sub(domains[0].strip())
    buf = []
    with open('/etc/nginx/sites-available/'+domain_parts['name']+'.'+domain_parts['tld'],'r') as f:
        buf = f.readlines()
    with open('/etc/nginx/sites-available/'+domain_parts['name']+'.'+domain_parts['tld'],'w') as f:
        for line in buf:
            if 'ssl_certificate ' in line:
                f.write('    ssl_certificate /etc/letsencrypt/live/'+domains[0].strip()+'/fullchain.pem;\n')
                continue
            if 'ssl_certificate_key ' in line:
                f.write('    ssl_certificate_key /etc/letsencrypt/live/'+domains[0].strip()+'/privkey.pem;\n')
                continue
            f.write(line)

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
        f.write('    ssl_certificate /etc/nginx/certs/server.crt;\n')
        f.write('    ssl_certificate_key /etc/nginx/certs/server.key;\n')
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
        '/etc/init.d/php7.4-fpm',
        'reload'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.stderr != b'':
        sys.stdout('Unable to reload PHP: %s\n' % res.stderr)
        sys.exit(1)
    res = subprocess.run([
        '/usr/sbin/nginx',
        '-s',
        'reload'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.stderr != b'':
        sys.stdout('Unable to reload NGINX: %s\n' % res.stderr)
        sys.exit(1)

def create_symlink(alias_domain_dir,domain_dir):
    """This function creates symlink for the alias domain"""
    os.symlink(domain_dir,alias_domain_dir)

def remove_symlink(alias_domain_dir):
    """This function removes symlink for the alias domain"""
    os.unlink(alias_domain_dir)

def add_nginx_virtualhost_alias(domain, alias_domain):
    """This function adds a new alias to NGINX virtualhost"""
    buf = []
    with open('/etc/nginx/sites-available/'+domain,'r') as f:
        buf = f.readlines()
    with open('/etc/nginx/sites-available/'+domain,'w') as f:
        for line in buf:
            if '    server_name ' in line:
                chunks = line.strip().strip(';').split()[1:]
                if alias_domain not in chunks:
                    chunks.append(alias_domain)
                line = '    server_name '+' '.join(chunks)+';\n'
            f.write(line)

def remove_nginx_virtualhost_alias(domain, alias_domain):
    """This function removes an alias from NGINX virtualhost"""
    buf = []
    with open('/etc/nginx/sites-available/'+domain,'r') as f:
        buf = f.readlines()
    with open('/etc/nginx/sites-available/'+domain,'w') as f:
        for line in buf:
            if '    server_name ' in line:
                chunks = line.strip().strip(';').split()[1:]
                if alias_domain in chunks:
                    chunks.remove(alias_domain)
                line = '    server_name '+' '.join(chunks)+';\n'
            f.write(line)

def get_alias_parent(alias_domain_dir):
    """This function returns the parent domain of an alias domain"""
    domain_dir = os.readlink(alias_domain_dir)
    domain = os.path.basename(domain_dir)
    return domain

def remove_alias_ssl_certs(domain, alias_domain):
    """This function removes the alias_domain from the letsencrypt renew process"""
    buf = []
    with open('/etc/letsencrypt/renewal/'+domain+'.conf', 'r') as f:
        buf = f.readlines()
    with open('/etc/letsencrypt/renewal/'+domain+'.conf', 'w') as f:
        for line in buf:
            if line.startswith(alias_domain+' ='):
                continue
            f.write(line)

####################################
######### MAIN STARTS HERE #########
def main():
    if os.getuid() != 0:
        sys.stdout.write('This program must be executed as root\n')
        sys.exit(1)
    try:
        opts, args = getopt.getopt(sys.argv[1:], "ha:d:A:f", ["help", "action=", "domain=", "alias=", "fakessl"])
    except getopt.GetoptError as err:
        usage()
        sys.exit(2)
    domain = None
    alias_domain = None
    action = None
    ssl_fake = False
    show_info = False
    if len(opts) == 0:
        usage()
        sys.exit(2)
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-a", "--action"):
            action = a
            if action not in ('add_domain','add_alias','remove_domain','remove_alias','get_certs','get_info'):
                sys.stdout.write("Unknown action %s\n" % action)
                usage()
                sys.exit(1)
        elif o in ("-d", "--domain"):
            domain = a
        elif o in ("-A", "--alias"):
            alias_domain = a
        elif o in ("-f", "--fakessl"):
            ssl_fake = True
        else:
            sys.stdout.write('Unknown option %s\n' % o)
            usage()
            sys.exit(1)

    if action == 'get_info':
        if domain == None and alias_domain == None:
            sys.stdout.write('Missing domain or alias domain\n')
            sys.exit(1)
        if domain != None and alias_domain != None:
            sys.stdout.write('Please specify only a domain or an alias domain\n')
            sys.exit(1)

        # check if domain already exists
        if domain != None:
            domain_parts = tld_and_sub(domain)
            base_domain_dir = os.path.join(BASE_ROOT,domain_parts['tld'])
            child_domain_dir = os.path.join(base_domain_dir,domain_parts['name']+'.'+domain_parts['tld'])
            domain = domain_parts['name']+'.'+domain_parts['tld']
            if not os.path.isdir(child_domain_dir):
                sys.stdout.write('Domain %s does not exist at %s\n' % (domain,child_domain_dir))
                sys.exit(1)

        # check if alias domain already exists
        if alias_domain != None:
            alias_domain_parts = tld_and_sub(alias_domain)
            base_alias_domain_dir = os.path.join(BASE_ROOT,alias_domain_parts['tld'])
            child_alias_domain_dir = os.path.join(base_alias_domain_dir,alias_domain_parts['name']+'.'+alias_domain_parts['tld'])
            alias_domain = alias_domain_parts['name']+'.'+alias_domain_parts['tld']
            if not (os.path.isdir(child_alias_domain_dir) or os.path.islink(child_alias_domain_dir)):
                sys.stdout.write('Alias domain %s does not exist at %s\n' % (alias_domain,child_alias_domain_dir))
                sys.exit(1)

        if domain != None:
            sys.stdout.write(pwd.getpwuid(os.stat(child_domain_dir).st_uid).pw_name+'\n')
            sys.exit(0)
        elif alias_domain != None:
            sys.stdout.write(pwd.getpwuid(os.stat(child_alias_domain_dir).st_uid).pw_name+'\n')
            sys.exit(0)

    elif action == 'add_domain':
        if domain == None:
            sys.stdout.write('Missing domain\n')
            sys.exit(1)

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
        #lock_password(user['username'])

        # create additional folders
        create_subfolders(user['username'],child_domain_dir)

        # create PHP pool
        create_php_pool(user['username'],domain,child_domain_dir)

        # create NGINX virtualhost
        create_nginx_virtualhost(domain,child_domain_dir)

        # obtain SSL certificates from letsencrypt
        if not ssl_fake:
            domains = domains_in_virtualhost(domain)
            check_update_ssl_certs(domains)

        # reload services (nginx + php-fpm)
        reload_services()

    elif action == 'add_alias':
        if domain == None:
            sys.stdout.write('Missing domain\n')
            sys.exit(1)
        if alias_domain == None:
            sys.stdout.write('Missing domain alias\n')
            sys.exit(1)

        # check if domain already exists
        domain_parts = tld_and_sub(domain)
        base_domain_dir = os.path.join(BASE_ROOT,domain_parts['tld'])
        child_domain_dir = os.path.join(base_domain_dir,domain_parts['name']+'.'+domain_parts['tld'])
        domain = domain_parts['name']+'.'+domain_parts['tld']
        if not os.path.isdir(child_domain_dir):
            sys.stdout.write('Domain %s does not exist at %s\n' % (domain,child_domain_dir))
            sys.exit(1)

        # check if alias domain already exists
        alias_domain_parts = tld_and_sub(alias_domain)
        base_alias_domain_dir = os.path.join(BASE_ROOT,alias_domain_parts['tld'])
        child_alias_domain_dir = os.path.join(base_alias_domain_dir,alias_domain_parts['name']+'.'+alias_domain_parts['tld'])
        alias_domain = alias_domain_parts['name']+'.'+alias_domain_parts['tld']
        if os.path.isdir(child_alias_domain_dir) or os.path.islink(child_alias_domain_dir):
            sys.stdout.write('Alias domain %s already exists at %s\n' % (alias_domain,child_alias_domain_dir))
            sys.exit(1)

        # add base folder if not exists
        if not os.path.isdir(base_domain_dir):
            os.mkdir(base_domain_dir)

        # create symlink
        create_symlink(child_alias_domain_dir,child_domain_dir)

        # add NGINX virtualhost alias
        add_nginx_virtualhost_alias(domain, alias_domain)

        # obtain SSL certificates from letsencrypt
        if not ssl_fake:
            domains = domains_in_virtualhost(domain)
            check_update_ssl_certs(domains)

        # reload services (nginx + php-fpm)
        reload_services()

    elif action == 'remove_domain':
        if domain == None:
            sys.stdout.write('Missing domain\n')
            sys.exit(1)

        # check if domain already exists
        domain_parts = tld_and_sub(domain)
        base_domain_dir = os.path.join(BASE_ROOT,domain_parts['tld'])
        child_domain_dir = os.path.join(base_domain_dir,domain_parts['name']+'.'+domain_parts['tld'])
        domain = domain_parts['name']+'.'+domain_parts['tld']
        if not os.path.isdir(child_domain_dir):
            sys.stdout.write('Domain %s does not exist at %s\n' % (domain,child_domain_dir))
            sys.exit(1)

        # remove php pool
        remove_php_pool(domain)

        # remove ssl certificates
        remove_ssl_certs(domain)

        # remove nginx virtualhost
        remove_nginx_virtualhost(domain)

        # reload services (nginx + php-fpm)
        reload_services()

        # remove domain folder
        remove_domain_folder(child_domain_dir)

        # remove user if present
        remove_user(child_domain_dir)

    elif action == 'remove_alias':
        if alias_domain == None:
            sys.stdout.write('Missing domain alias\n')
            sys.exit(1)

        # check if alias domain already exists
        alias_domain_parts = tld_and_sub(alias_domain)
        base_alias_domain_dir = os.path.join(BASE_ROOT,alias_domain_parts['tld'])
        child_alias_domain_dir = os.path.join(base_alias_domain_dir,alias_domain_parts['name']+'.'+alias_domain_parts['tld'])
        alias_domain = alias_domain_parts['name']+'.'+alias_domain_parts['tld']
        if not os.path.islink(child_alias_domain_dir):
            sys.stdout.write('Alias domain %s does not exist at %s\n' % (alias_domain,child_alias_domain_dir))
            sys.exit(1)

        # get alias parent
        domain = get_alias_parent(child_alias_domain_dir)

        # remove domain folder
        remove_symlink(child_alias_domain_dir)

        # remove ssl certificates
        remove_alias_ssl_certs(domain, alias_domain)

        # remove nginx virtualhost
        remove_nginx_virtualhost_alias(domain, alias_domain)

        # reload services (nginx + php-fpm)
        reload_services()

    elif action == 'get_certs':
        if domain == None:
            sys.stdout.write('Missing domain\n')
            sys.exit(1)

        # check if domain already exists
        domain_parts = tld_and_sub(domain)
        base_domain_dir = os.path.join(BASE_ROOT,domain_parts['tld'])
        child_domain_dir = os.path.join(base_domain_dir,domain_parts['name']+'.'+domain_parts['tld'])
        domain = domain_parts['name']+'.'+domain_parts['tld']
        if not os.path.isdir(child_domain_dir):
            sys.stdout.write('Domain %s does not exist at %s\n' % (domain,child_domain_dir))
            sys.exit(1)

        domains = domains_in_virtualhost(domain)
        check_update_ssl_certs(domains)

        # reload services (nginx + php-fpm)
        reload_services()

if __name__ == "__main__":
    main()
