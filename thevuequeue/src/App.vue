<template>
  <v-app>
    <v-app-bar app dense>
      <v-toolbar-title>The Vue Queue</v-toolbar-title>

      <v-spacer></v-spacer>

      <v-btn
        v-for="item in navItems"
        :key="item.route"
        :to="{ name: item.route }"
        text
      >
        {{ item.name }}
      </v-btn>
    </v-app-bar>

    <v-main>
      <router-view />
    </v-main>
  </v-app>
</template>

<script>
export default {
  data() {
    return {
      navItems: [
        {
          route: "WhatToWatch",
          name: "What to watch"
        },
        {
          route: "Feed",
          name: "Feed"
        },
        {
          route: "Submissions",
          name: "Submissions"
        },
        {
          route: "MyAccount",
          name: "My account"
        }
      ]
    };
  }
};
</script>
