#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ==============================================================================

import sys
import os
import lxml.objectify
import lxml.etree

# ==============================================================================
f = sys.stdin.read()
data = lxml.objectify.parse(f).getroot()

# check all auth methods present
for i in data.EAPIdentityProvider.AuthenticationMethods:
  s = i.find("AuthenticationMethod")    # search AuthenticationMethod in i

  if s != None:                         # found AuthenticationMethod
    s = s.find("ServerSideCredential")  # search ServerSideCredential in subtree

    if s != None:                       # found ServerSideCredential
      s = s.find("CA")                  # search CA in subtree

      if s != None:                     # found CA
        print(lxml.etree.tostring(i.AuthenticationMethod.ServerSideCredential.CA).decode('utf-8'))

      else:
        print("No certificate present in profile " + os.path.basename(f) + " for AuthenticationMethod " + i.AuthenticationMethod.EAPMethod.Type.text)
        sys.exit(1)
