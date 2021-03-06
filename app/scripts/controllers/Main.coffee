###!
Copyright (c) 2002-2016 "Neo Technology,"
Network Engine for Objects in Lund AB [http://neotechnology.com]

This file is part of Neo4j.

Neo4j is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
###

'use strict'

angular.module('neo4jApp.controllers')
  .config ($provide, $compileProvider, $filterProvider, $controllerProvider) ->
    $controllerProvider.register 'MainCtrl', [
      '$rootScope',
      '$window'
      '$q'
      'Server'
      'Frame'
      'Settings'
      'SettingsStore'
      'motdService'
      'UsageDataCollectionService'
      'Utils'
      'CurrentUser'
      'ProtocolFactory'
      ($scope, $window, $q, Server, Frame, Settings, SettingsStore, motdService, UDC, Utils, CurrentUser, ProtocolFactory) ->
        $scope.CurrentUser = CurrentUser
        initailConnect = yes

        $scope.sojoboMetrics =
          is_connected   : false
          hauchiwas      : 0
          max_containers : 0
          max_machines   : 0
          avg_containers : 0
          avg_machines   : 0

        setSojoboMetrics = () ->
          req = {
            "method"  : "GET"
            "url"     : $scope.sojobo_url+"/hauchiwa"
          }
          $http(req).then(
            (response) ->
              containers = 0
              machines = 0
              angular.forEach(response.data.services, (unit, key) ->
                if key.startsWith "h-"
                  $scope.sojoboMetrics.hauchiwas++
                  ## todo metrics from individual hauchiwas
              )
            , (r) ->
              console.log("Not Connected to Sojobo. could not retrieve metrics.")
          )

        $scope.kernel = {}
        $scope.refresh = ->
          return '' if $scope.unauthorized || $scope.offline
          $scope.server = Server.info $scope.server
          $scope.host = $window.location.host
          $q.when()
          .then( ->
            ProtocolFactory.getMetaService().getMeta().then((res) ->
              $scope.labels = res.labels
              $scope.relationships = res.relationships
              $scope.propertyKeys = res.propertyKeys
            )
          ).then( ->
            ProtocolFactory.getVersionService().getVersion($scope.version).then((res) ->
              $scope.version = res
            )
          ).then( ->
            setSojoboMetrics()
          )

        refreshAllowOutgoingConnections = (allow_connections) ->
          return unless $scope.neo4j.config.allow_outgoing_browser_connections != allow_connections
          allow_connections = if $scope.neo4j.enterpriseEdition then allow_connections else yes
          mapServerConfig 'allow_outgoing_browser_connections', allow_connections
          if allow_connections
            $scope.motd.refresh()
            UDC.loadUDC()
          else if not allow_connections
            UDC.unloadUDC()

        mapServerConfig = (key, val) ->
          return unless $scope.neo4j.config[key] != val
          $scope.neo4j.config[key] = val

        $scope.identity = angular.identity

        $scope.motd = motdService

        $scope.neo4j =
          license =
            type: "GPLv3"
            url: "http://www.gnu.org/licenses/gpl.html"
            edition: 'community'
            enterpriseEdition: no
        $scope.neo4j.config = {}

        $scope.tengu =
          license =
            type: "AGPLv3"
            version: "0.4"
            url: "http://www.fsf.org/licensing/licenses/agpl-3.0.html"
            edition: 'Open Source'
            enterpriseEdition: no
        $scope.tengu.config = {}

        $scope.$on 'db:changed:labels', $scope.refresh

        $scope.today = Date.now()
        $scope.cmdchar = Settings.cmdchar

        $scope.goodBrowser = !/msie/.test(navigator.userAgent.toLowerCase())

        $scope.$watch 'offline', (serverIsOffline) ->
          console.log("watch offline: " + serverIsOffline)
          if (serverIsOffline?)
            if not serverIsOffline
              Frame.createOne({input:"#{Settings.cmdchar}signin"})

        ###
        setAndSaveSetting = (key, value) ->
          Settings[key] = value
          SettingsStore.save()
        ###

        ###
        onboardingSequence = ->
          Frame.createOne({input:"#{Settings.cmdchar}play neo4j-sync"})
          setAndSaveSetting('onboarding', false)
        ###

        pickFirstFrame = ->
          CurrentUser.init().then(
            (success) ->
              Frame.closeWhere "#{Settings.cmdchar}signin"
              Frame.create({input:"#{Settings.initCmd}"})
            , (error) ->
              Frame.createOne({input:"#{Settings.cmdchar}signin"})
          )

        pickFirstFrame()

        executePostConnectCmd = (cmd) ->
          return unless cmd
          return unless initailConnect
          initailConnect = no
          Frame.create({input:"#{Settings.cmdchar}#{cmd}"})

        $scope.$on 'ntn:data_loaded', (evt, authenticated, newUser) ->
          return Frame.createOne({input:"#{Settings.initCmd}"}) if !$scope.offline
          return Frame.create({input:"#{Settings.cmdchar}play welcome"}) if newUser
          return Frame.create({input:"#{Settings.cmdchar}server connect"}) if !newUser

        ###
        $scope.$watch 'version', (val) ->
          return '' if not val
          $scope.neo4j.version = val.version
          $scope.neo4j.edition = val.edition
          $scope.neo4j.enterpriseEdition = val.edition is 'enterprise'

          $scope.tengu.version = val.version
          $scope.tengu.edition = val.edition
          $scope.tengu.enterpriseEdition = val.edition is 'enterprise'

          $scope.$emit 'db:updated:edition', val.edition
          if val.version then $scope.motd.setCallToActionVersion(val.version)
        , true
        ###
    ]

  .run([
    '$rootScope'
    'Utils'
    'Settings'
    'Editor'
    ($scope, Utils, Settings, Editor) ->
      $scope.unauthorized = yes
      $scope.apis = []

      if cmdParam = Utils.getUrlParam('cmd', window.location.href)
        return unless cmdParam[0] is 'play'
        cmdCommand = "#{Settings.cmdchar}#{cmdParam[0]} "
        cmdArgs = Utils.getUrlParam('arg', decodeURIComponent(window.location.href)) || []
        Editor.setContent(cmdCommand + cmdArgs.join(' '))
  ])
