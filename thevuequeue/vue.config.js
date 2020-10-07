module.exports = {
  outputDir: "../public/thevuequeue",
  publicPath: "/thevuequeue/",
  devServer: {
    proxy: "http://localhost:3000"
  },
  transpileDependencies: ["vuetify"]
};
