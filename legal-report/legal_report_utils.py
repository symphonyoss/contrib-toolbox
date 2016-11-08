import os
import urllib2
import re
import glob
import yaml
import sys
import json
from github import Github

report_template_file = "{}/report-template.html".format(os.path.dirname(os.path.realpath(__file__)))

def loadConfig():
    if len(sys.argv) > 1:
        configFile = sys.argv[1]
    else:
        configFile = "license_report_config.yaml"
    with open(configFile, 'r') as stream:
        try:
            config = yaml.load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    config['excluded_files_re'] = "" "(" + ")|(".join(config['excluded_files_list']) + ")"

    if 'output' in config:
        config['report_dir'] = os.path.abspath(config['output'])

    return config

def executeCommands(config):
    if 'execute_commands' in config:
        for command in config['execute_commands']:
            print "Executing command '{}'".format(command)
            os.popen(command)

def replaceInFile(filePath,placeholder,value):
    with open("report.html", "wt") as fout:
        with open(filePath, "rt") as fin:
            for line in fin:
                fout.write(line.replace(placeholder, value))

def checkGithubOrg(config):
    currentDir = os.getcwd()
    projects = {}
    g = Github(config['github_token'])
    repos = g.get_organization(config['github_org']).get_repos()
    for repo in repos:
        if 'include_github_repos' in config and not repo.name in config['include_github_repos']:
            print "repo '{}' is not included in 'include_github_repos'".format(repo.name)
            continue
        if 'exclude_github_repos' in config and repo.name in config['exclude_github_repos']:
            print "repo '{}' is excluded in 'exclude_github_repos'".format(repo.name)
            continue
        project_checkout_folder = "{}/{}".format(config['github_checkout_folder'],repo.name)
        if os.path.exists(project_checkout_folder):
            print "pulling on {}".format(project_checkout_folder)
            os.chdir(project_checkout_folder)
            project_checkout_folder = "."
            os.popen("git checkout master >/dev/null 2>&1")
            os.popen("git pull >/dev/null 2>&1")
        else:
            print "cloning on {}".format(project_checkout_folder)
            os.popen("git clone {} {} >/dev/null 2>&1".format(repo.clone_url, project_checkout_folder))

        if 'master_only' in config and config['master_only'] is True:
            checkProject(projects,config,repo.name,project_checkout_folder,'master')
        else:
            # Iterate over branches
            branches = os.popen('git branch -a').read().splitlines()
            for branch in branches:
                branch = branch.strip()
                if branch.startswith('remotes/'):
                    if "->" in branch:
                        branch = branch.split("->",1)[0].strip()
                    os.popen("git checkout {} >/dev/null 2>&1".format(branch))
                    checkProject(config,project_checkout_folder,branch)
        os.chdir(currentDir)

    if 'output_format' in config and config['output_format'] == "html":
        print "html out"
        myjson = json.dumps(flattenHash(projects))
        replaceInFile(report_template_file,"{{JSON_VAR}}",myjson)

def checkProject(projects,config,project_name,project_checkout_folder,branch):
    violations = {}
    checkNoticeFile(config,violations)
    checkLicenseFile(config,violations)
    executeCommands(config)
    walk(violations,config,project_checkout_folder)
    if violations:
        if 'output' in config:
            if not os.path.isdir(config['report_dir']):
                os.makedirs(config['report_dir'])
            if 'output_format' in config and config['output_format'] == 'json':
                output_file = "{}/report-{}-{}.json".format(config['report_dir'],project_name,branch)
                print("Exporting project results on file {}".format(output_file))
                with open(output_file, 'w+') as outfile:
                    json.dump(flattenHash(violations), outfile)

        else:
            print("Printing out results for project '{}', branch '{}'".format(project_checkout_folder,branch))
            print(flattenHash(violations))
    else:
        print("No issues found on project '{}', branch '{}'".format(project_checkout_folder,branch))
    projects[project_name] = flattenHash(violations)

def checkFile(violations,config,root,name):
    filePath = root + "/" + name
    with open(filePath) as search:
        for line in search:
            line = line.rstrip()  # remove '\n' at end of line
            checkLine(violations,filePath,line,config['category_b_licenses'],'categoryB')
            checkLine(violations,filePath,line,config['category_x_licenses'],'categoryX')
    search.close()

def checkLine(violations,filePath, line,licenses,category):
    for license in licenses:
        if license in line:
            if not filePath in violations:
                violations[filePath] = []
            violation = createViolation("LGL-4","Third-party code license warning",license,category,line)
            violations[filePath].append(violation)

def walk(violations,config,folder):
    for root, dirs, files in os.walk(folder, topdown=False):
            for name in files:
                if not re.match(config['excluded_files_re'], root + name):
                    checkFile(violations,config,root,name)
            for name in dirs:
                if not re.match(config['excluded_files_re'], root + name):
                    walk(violations,config,name)

def flattenHash(input_raw):
    result = {}
    for key,value in input_raw.items():
        if value not in result.values():
            result[key] = value
    return result

def createViolation(id,description,license,license_category,line):
    violation = {}
    violation['id'] = id
    violation['description'] = description
    if license: violation['license'] = license
    if license_category: violation['license_category'] = license_category
    if line: violation['line'] = line
    return violation

def checkLicenseFile(config,violations):
    globs = glob.glob('LICENSE*') + glob.glob('license*')
    if not globs:
        if not 'LICENSE' in violations:
            violations['LICENSE'] = []
        violation = createViolation("LGL-1","Missing LICENSE file",None,None,None)
        violations['LICENSE'].append(violation)
    else:
        for match in config['license_file_matches']:
            if not match in open(globs[0]).read():
                if not 'LICENSE' in violations:
                    violations['LICENSE'] = []
                violation = createViolation("LGL-1","LICENSE file not matching '{}'".format(match),None,None,None)
                violations[globs[0]].append(violation)
                break

def checkNoticeFile(config,violations):
    globs = glob.glob('NOTICE*') + glob.glob('notice*')
    if not globs:
        if not 'NOTICE' in violations:
            violations['NOTICE'] = []
        violation = createViolation("LGL-2","Missing NOTICE file",None,None,None)
        violations['NOTICE'].append(violation)
