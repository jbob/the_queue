<template>
  <v-container>
    <v-row>
      <v-col>
        <h1>Submissions</h1>
        <div v-if="!done">{{ status }}</div>
      </v-col>
    </v-row>
    <v-row v-if="done">
      <v-col v-for="(sub, index) in submissions" :key="index">
        {{ sub.title }}
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
export default {
  data() {
    return {
      status: "",
      submissions: []
    };
  },
  computed: {
    done() {
      return this.status === "ready";
    }
  },
  mounted() {
    this.status = "loading";
    fetch("/api/submissions")
      .then(resp => resp.json())
      .then(({submissions}) => {
        this.submissions = submissions;
        this.status = "ready";
      })
      .catch(() => {
        this.status = "failed";
      });
  }
};
</script>
