"""invoke tasks"""
from invoke import task

@task
def validate(ctx):
    """style and lint tests"""
    ctx.run('yamllint .')
    ctx.run('terraform fmt -check=false')
    ctx.run('docker run --rm -v $(pwd) -t wata727/tflint --error-with-issues')
    ctx.run('pylint tasks.py')

@task
def enc(ctx, file='local.env', encoded_file='env.ci'):
    """encrypt local file"""
    ctx.run("openssl aes-256-cbc -e -in {} -out {} -k $GRAINGER_CIRCLECI_ENC".format(file, encoded_file))

@task
def dec(ctx, encoded_file='env.ci', file='local.env'):
    """decrypt local file"""
    ctx.run("openssl aes-256-cbc -d -in {} -out {} -k $GRAINGER_CIRCLECI_ENC".format(encoded_file, file))
