(function() {
  'use strict';
  angular
    .module("AppCatalog", ["ngRoute"])
    .filter("assetLink", function() {
      // Convert dependency link to app catalog link
      return function(input) {
      var bits = input.split("/");
      return "#/assets/" + bits[2] + "/" + bits[3];
    };})
    .filter("blobLink", function() {
      return function(artifact, type, blobFieldName) {
        return window.location.protocol + "//" + window.location.host + "/api/v2/db/artifacts/"
          + type + "/" + artifact.id + "/" + blobFieldName;
      };
    })
    .config(function($routeProvider) {
      $routeProvider
      .when("/", {
        templateUrl: "static/html/index.html"
      })
      .when("/add/:type", {
        templateUrl: "static/html/edit.html",
        controllerAs: "vm",
        controller: "EditAssetController"
      })
      .when("/artifacts/:type/:id", {
        templateUrl: "static/html/asset.html",
        controllerAs: "vm",
        controller: "DisplayAssetController"
      })
      .when("/private/:type/:id", {
        templateUrl: "static/html/asset.html",
        controllerAs: "vm",
        controller: "DisplayAssetController"
      })
      .when("/list/:visibility/:type/", {
        templateUrl: "static/html/assets.html",
        controllerAs: "vm",
        controller: "ListAssetsController"
      })
      .when("/edit/:type/:id", {
        templateUrl: "static/html/edit.html",
        controllerAs: "vm",
        controller: "EditAssetController"
      });
    })
    .run(function($rootScope, $http) {
      $rootScope.$on("$locationChangeStart", function(event, next, current) {
        var nav = document.getElementById("navbar").children;
        var type = next.split('/');
        type = type[type.length - 2];
        for (var i = 0; i < nav.length; i++) {
          if (type.length > 5 && (nav[i].firstChild.href.indexOf(type) > 0)) {
            nav[i].className = "active";
          } else {
            nav[i].className = "";
          }
        }
      });
      $http.get("/auth/info").then(function(response) {
        $rootScope.auth_info = response.data;
        if ('launchpad_teams' in response.data) {
          $rootScope.logged_in = true;
          $rootScope.is_admin = response.data.launchpad_teams.indexOf('mirantis') >= 0;
        }
      });
      $http.defaults.headers.patch = {'Content-Type': 'application/json-patch+json'};
    })
    .factory("UrlService", function() {
      return {
        getUrl: getUrl,
        getApiUrl: getApiUrl
      };
    });
  function getUrl(start, bits, args) {
    var url = start;
    for (var i = 0; i < bits.length; i++) {
      url += "/" + bits[i];
    }
    var query = [];
    for (var arg in args) {
      if ('undefined' !== typeof args[arg]) {
        query.push(arg + "=" + args[arg]);
      }
    }
    if (query) {
      url += "?" + query.join("&");
    }
    return url;
  }
  function getApiUrl(bits, args) {
    return getUrl("/api/v2/db", bits, args);
  }
})();
