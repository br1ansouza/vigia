self.addEventListener("push", (evento) => {
  const aviso = evento.data ? evento.data.json() : {titulo: "Vigia", corpo: ""}
  evento.waitUntil(
    self.registration.showNotification(aviso.titulo, {
      body: aviso.corpo,
      icon: "/icons/icone-192.png",
      badge: "/icons/icone-192.png",
      data: {url: aviso.url || "/"},
    })
  )
})

self.addEventListener("notificationclick", (evento) => {
  evento.notification.close()
  evento.waitUntil(clients.openWindow(evento.notification.data.url))
})
