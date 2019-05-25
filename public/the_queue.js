document.addEventListener('DOMContentLoaded', () => {
    const $navbarBurgers = Array.prototype.slice.call(document.querySelectorAll('.navbar-burger'), 0)
    if ($navbarBurgers.length > 0) {
        $navbarBurgers.forEach( el => {
            el.addEventListener('click', () => {
                const target = el.dataset.target
                const $target = document.getElementById(target)
                el.classList.toggle('is-active')
                $target.classList.toggle('is-active')
            })
        })
    }
})

document.querySelectorAll('.submission-action').forEach(link => {
    link.addEventListener('click', event => {
        performStuff(link, event)
    })
})

function performStuff (element, event) {
    const href = element.getAttribute('href')
    const action = href.replace(/submissions\/(\w+)\/.*/, "$1")

    let onSuccess

    switch (action) {
        case 'delete':
            onSuccess = function () {
                element.parentNode.parentNode.remove()
            }
            break
        case 'done':
            onSuccess = function () {
                element.querySelector('span.icon').classList.toggle('has-text-success')
            }
            break
        case 'available':
            onSuccess = function () {
                element.querySelector('span.icon').classList.toggle('has-text-success')
            }
            break
        case 'thumbs':
            onSuccess = function () {
                element.querySelector('span.icon').classList.toggle('has-text-success')
            }
            break
        default:
            return
    }

    // kill click for we don't want no navigation
    event.preventDefault()

    fetch(href, {headers: {accept: 'application/json'}})
        .then(response => {
            if (response.ok) {
                onSuccess()
            } else {
                console.error('Something is b0rked.', response)
            }
        })
}
