import Vue from "vue";
import VueRouter from "vue-router";
import WhatToWatch from "../views/WhatToWatch.vue";
import Feed from "../views/Feed.vue";
import Submissions from "../views/Submissions.vue";
import MyAccount from "../views/MyAccount.vue";

Vue.use(VueRouter);

const routes = [
  {
    path: "/",
    redirect: { name: "WhatToWatch" }
  },
  {
    path: "/wtw",
    name: "WhatToWatch",
    component: WhatToWatch
  },
  {
    path: "/feed",
    name: "Feed",
    component: Feed
  },
  {
    path: "/submissions",
    name: "Submissions",
    component: Submissions
  },
  {
    path: "/account",
    name: "MyAccount",
    component: MyAccount
  }
];

const router = new VueRouter({
  routes
});

export default router;
