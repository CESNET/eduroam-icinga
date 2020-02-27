#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ==============================================================================
# check eap certificate properties 
# params:
# 1) realm
# 
# other params:
# this program internally uses rad_eap_test to get remote RADIUS server certificate
# so all the necesarry params for rad_eap_test are required
# ==============================================================================


# imports
# ==============================================================================
import sys
import os
import json
import subprocess
import tempfile
import json
import urllib.request
import lxml.etree
import lxml.objectify
# ==============================================================================


# ==============================================================================
# check eduroam CAT for institution by realm
# ==============================================================================
def check_CAT(realm):
  # check if institution is in eduroam CAT
  # if the institution is present, also download the eap-config
  proc = subprocess.Popen([os.path.dirname(os.path.realpath(__file__)) + "/eduroam_cat.sh", "-p", realm], stdout=subprocess.PIPE, stderr=subprocess.PIPE)   # run process
  proc.wait(30)     # wait max 30 seconds for process to finish running

 
  if proc.returncode == 0:      # present in CAT, got config and visible installers
    parse_eap_config(realm, proc.stdout)

  #elif proc.returncode == 1:    # present in CAT, but has some problems
  #  # TODO - tady to jeste trochu lepe rozlisit na zaklade vystupu?
  #  # tady muze byt instituce, ktera nema nic (empty)
  #  # a nebo muze mit dostupny instalator (C), ale nema nic ke stazeni (chybi V)


  # udrzovat databazi certifikatu:
  # lokalne udrzovat db certifikatu
  # test eduroam_cat by mohl aktualizovat db
  # chain per realm
  # nejak perzistentne

  # wpa supplicant:
  # dodatecna konfigurace pro validaci certifikatu:
  # CA file
  # + bude potreba parsovat hostname EAP serveru z konfiguraku z CATu


  # delat ruzne testy:
  # roztridit do kategorii: informativni, warning, critical 
  # trideni vzit z CATu
  # 
  # navratovy kod bude odpovidat nejkritictejsi nelezene kategorii


  # =====================
  # tento test bude delat ciste analyzu EAP certifikatu serveru
  # pripadne validaci proti certifikatu z CATu?
  # =====================


  #  get_problematic_inst()

  elif proc.returncode == 2:    # NOT present in CAT
    pass

  else:      # UNKNOWN, TODO
    pass

  #print(proc)

# ==============================================================================
# get eap config for specific institution
# ==============================================================================
def parse_eap_config(realm, inst_details):
  db = "/var/lib/nagios/eap_cert_db"

  # read output ot child process, decode as utf-8, split by newlines and take only the first one
  profile_id = inst_details.read().decode('utf-8').split('\n')[0]

  # TODO - check if the file exists
  # read eap config for given realm and profile id
  data = lxml.objectify.parse(db + "/" + realm + "_" + profile_id + "_eap_config.xml").getroot()

  # TODO - how does chain look like in xml?
  CA_cert = data.EAPIdentityProvider.AuthenticationMethods.AuthenticationMethod.ServerSideCredential.CA

  # TODO - do not write the file each time, do diff

  f = open(db + "/" + realm + "_" + profile_id + "_chain.pem", "w+")
  f.write("-----BEGIN CERTIFICATE-----\n" + str(CA_cert) + "\n-----END CERTIFICATE-----")
  f.close()
  
  server = data.EAPIdentityProvider.AuthenticationMethods.AuthenticationMethod.ServerSideCredential.ServerID


# ==============================================================================
# run rad_eap_test
# ==============================================================================
def run_rad_eap_test(args):
  proc = subprocess.Popen([os.path.dirname(os.path.realpath(__file__)) + "/rad_eap_test", args, "-B "], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

# ==============================================================================
# main function
# ==============================================================================
def main(args):
  check_CAT(args[0])

# ==============================================================================
# program is run directly, not included
# ==============================================================================
if __name__ == "__main__":
  main(sys.argv[1:])

