document.querySelectorAll('. submission-action').forEach(link => {
    link.addEventListener('click', event => {
        // do the thing
        performStuff(link, event);
    });
});

function performStuff (element, event) {
    const href = element.getAttribute('href');
    const action = href.replace(/submissions\/(\w+)\/.*/, "$1')");

    let onSuccess;

    switch (action) {
        case 'delete':
            onSuccess = function () {
                console.info('delete successful.');
                element.parentNode.parentNode.remove();
            };
            break;

        case 'done':
            onSuccess = function () {
                console.info('done successful.');
                element.querySelector('span.icon').classList.toggle('has-text-success');
            };
            break;

        case 'thumbs':
            onSuccess = function () {
                console.info('thumbs successful.');
                element.querySelector('span.icon').classList.toggle('has-text-success');
            };
            break;

        default:
            console.error('wtf lol bbq. You managed to click an invalid thingy.');
            return;
    }

    // kill click for we don't want no navigation
    event.preventDefault();

    fetch(href, {headers: {accept: 'application/json'}})
        .then(response => {
            if (response.ok) {
                onSuccess();
            } else {
                console.error('Something is b0rked.', response);
            }
        });

}
