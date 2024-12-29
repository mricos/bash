const retainCountKey = 'retainCount';
const retainCountInput = document.getElementById('retain_count');
const dataList = document.getElementById('data_list');
const pauseButton = document.getElementById('pause_button');

retainCountInput.value = localStorage.getItem(retainCountKey) || 5;

retainCountInput.addEventListener('change', () => {
    localStorage.setItem(retainCountKey, retainCountInput.value);
});

let lastTimestamp = null;
let paused = false;
function updateDataList(newData) {
    const currentTimestamp = new Date(newData.timestamp);
    if (lastTimestamp) {
        const deltaTime = currentTimestamp - lastTimestamp;
        newData.deltatime = deltaTime;
    }
    lastTimestamp = currentTimestamp;

    const li = document.createElement('li');
    li.textContent = JSON.stringify(newData);
    dataList.prepend(li);

    const retainCount = parseInt(retainCountInput.value);
    while (dataList.childElementCount > retainCount) {
        dataList.removeChild(dataList.lastChild);
    }
}

const ws = new WebSocket('ws://localhost:8080');
ws.onmessage = (event) => {
    if (!paused) {
        const data = JSON.parse(event.data);
        updateDataList(data);
    }
};
ws.onerror = (error) => {
    console.error('WebSocket error:', error);
};
ws.onclose = (event) => {
    console.log('WebSocket connection closed:', event);
};

pauseButton.addEventListener('click', () => {
    paused = !paused;
    pauseButton.textContent = paused ? 'Resume' : 'Pause';
});
