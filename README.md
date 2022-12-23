# upload-packagecloud

GitHub Action to upload packages to PackgeCloud.io.

All the other similar actions out there have flaws and do not meet my needs.
This one probably has flaws too, but it tries to be better.
If you need any other features, please [ask](https://github.com/golift/upload-packagecloud/issues/new).

## Inputs

- Version 1 has three required inputs: `userrepo`, `apitoken` and `packages`.

### userrepo

This required input must be the `username/repository` on package cloud that the packages are uploaded to.

### apitoken

Store your Package Cloud API token in GitHub Secrets and pass it in here.

### packages

This input may be either a folder or a single file name.
If it's a single file, any package type is supported,
but you have little control over the "distribution version" for non-RPM/DEB package types.
If a folder is provided, all `*.deb` and `*.rpm` files in it (non-recusrive) are uploaded.
No other package types are supported for a folder input.

### rpmdists

This optional field controls which YUM distribtions RPM packages are uploaded to.
Specify more than 1 by separating them with spaces.
Examples: `el/6 el/7 ol/6 ol/7`

### debdists

This optional field controls which APT distribtions DEB packages are uploaded to.
Specify more than 1 by separating them with spaces.
Examples: `debian/buster ubuntu/focal`

## Example Use

```yaml
- uses: golift/upload-packagecloud@v1
  with:
    userrepo: golift/pkgs
    apitoken: ${{ secrets.PACKAGECLOUD_TOKEN }}
    packages: .
    rpmdists: el/6
    debdists: ubuntu/focal ubuntu/xenial
```