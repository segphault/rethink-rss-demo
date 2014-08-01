var app = angular.module("news", ["ngSanitize", "ngDialog"]);

app.filter("plainText", function() {
  return function(input) {
    return input.replace(/(<([^>]+)>)/ig,"");
  }
});

app.controller("MainController", [
  "$rootScope", "$scope", "$http", "ngDialog",
  function($rootScope, $scope, $http, ngDialog) {

    $scope.loadFeeds = function() {
      $http.get("/feed").success(
        function(data, stat, headers, conf) {
          $scope.feeds = data;
        });
    };

    $scope.loadPosts = function() {
      var id = $scope.selectedFeed.id;
      $http.get("/feed/" + id + "/posts").success(
        function(data, stat, headers, conf) {
          data.posts.forEach(function(p) {
            p.date = new Date(p.published);
          });

          $scope.posts = data.posts;
        });
    };

    $scope.selectFeed = function(feed) {
      $scope.selectedFeed = feed;
      $scope.loadPosts();
    };

    $scope.selectPost = function(post) {
      $scope.selectedPost = post;
    }

    $scope.removeSelectedFeed = function() {
      $http({
        method: "DELETE",
        url: "/feed/" + $scope.selectedFeed.id
      }).success(function(data, stat, headers, conf) {
        for (var i = 0; i < $scope.feeds.length; i++)
          if ($scope.feeds[i].id == $scope.selectedFeed.id) {
            $scope.selectedFeed = null;
            return $scope.feeds.splice(i, 1);
          }
      });
    }

    $scope.addFeed = function(title, url) {
      $http({
        method: "POST", url: "/feed",
        params: {title: title, url: url},
      }).success(function(data, stat, headers, conf) {
        $scope.feeds.push(data.feed);
      });
      ngDialog.close();
    }

    $scope.openAddFeedDialog = function() {
      ngDialog.open({
        template: 'dialog',
        scope: $scope
      });
    }

    $scope.loadFeeds()

}]);
