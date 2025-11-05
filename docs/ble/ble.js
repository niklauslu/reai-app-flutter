/**
 * 蓝牙管理类
 * 使用Web Bluetooth API与DYJ-V2设备通信
 */
class BLEManager {
    constructor() {
        // 蓝牙服务UUID
        this.SERVICE_UUID = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
        
        // 连接状态
        this.device = null;
        this.server = null;
        this.service = null;
        this.txCharacteristic = null;
        this.rxCharacteristic = null;
        this.isConnected = false;
        
        // 事件回调
        this.onConnectionChange = null;
        this.onDataReceived = null;
        this.onError = null;
        
        // 特征值信息
        this.characteristicsInfo = {
            tx: null,
            rx: null,
            notificationsEnabled: false,
            receiveCount: 0,
            totalBytes: 0,
            lastReceiveTime: null
        };
        
        // 接收缓冲区（用于处理UART标准协议）
        this.receiveBuffer = '';
        
        // 文件接收相关
        this.fileReceiveBuffer = new Uint8Array(0);
        this.isReceivingFile = false;
        this.currentFileName = '';
        this.onFileDataReceived = null;
        
        // 调试信息
        this.receiveCount = 0;
        this.lastReceiveTime = null;
        this.characteristicsDetails = null;
        
        // MTU相关
        this.mtu = 23; // 默认MTU值
        this.maxChunkSize = 20; // 默认分片大小
        this.mtuNegotiated = false;
    }
    
    /**
     * 检查浏览器是否支持Web Bluetooth
     */
    isBluetoothSupported() {
        return navigator.bluetooth !== undefined;
    }
    
    /**
     * 连接到蓝牙设备
     */
    async connect() {
        try {
            if (!this.isBluetoothSupported()) {
                throw new Error('此浏览器不支持Web Bluetooth API');
            }
            
            console.log('开始搜索蓝牙设备...');
            
            // 请求蓝牙设备
            this.device = await navigator.bluetooth.requestDevice({
                filters: [
                    { services: [this.SERVICE_UUID] },
                    { namePrefix: 'DYJ' },
                    { namePrefix: 'XIAO' }
                ],
                optionalServices: [this.SERVICE_UUID]
            });
            
            console.log('找到设备:', this.device.name);
            
            // 监听设备断开事件
            this.device.addEventListener('gattserverdisconnected', () => {
                this.handleDisconnection();
            });
            
            // 连接到GATT服务器
            console.log('连接到GATT服务器...');
            this.server = await this.device.gatt.connect();
            
            // 获取主要服务
            console.log('获取蓝牙服务...');
            this.service = await this.server.getPrimaryService(this.SERVICE_UUID);
            
            // 动态获取特征
            console.log('获取特征...');
            await this.discoverCharacteristics();
            
            // 启用通知
            console.log('启用数据接收通知...');
            await this.rxCharacteristic.startNotifications();
            this.characteristicsInfo.notificationsEnabled = true;
            this.rxCharacteristic.addEventListener('characteristicvaluechanged', (event) => {
                this.handleDataReceived(event);
            });
            
            // 协商MTU
            console.log('协商MTU...');
            await this.negotiateMTU();
            
            this.isConnected = true;
            console.log('蓝牙连接成功!', {
                device: this.device.name,
                mtu: this.mtu,
                maxChunkSize: this.maxChunkSize
            });
            
            if (this.onConnectionChange) {
                this.onConnectionChange(true, this.device.name);
            }
            
        } catch (error) {
            console.error('蓝牙连接失败:', error);
            this.handleDisconnection();
            throw error;
        }
    }
    
    /**
     * 断开蓝牙连接
     */
    async disconnect() {
        try {
            if (this.device && this.device.gatt.connected) {
                await this.device.gatt.disconnect();
            }
        } catch (error) {
            console.error('断开连接时出错:', error);
        }
        
        this.handleDisconnection();
    }
    
    /**
     * 处理连接断开
     */
    handleDisconnection() {
        this.isConnected = false;
        this.server = null;
        this.service = null;
        this.txCharacteristic = null;
        this.rxCharacteristic = null;
        
        // 重置接收缓冲区
        this.receiveBuffer = '';
        
        // 重置特征值信息
        this.characteristicsInfo = {
            tx: null,
            rx: null,
            notificationsEnabled: false,
            receiveCount: 0,
            totalBytes: 0,
            lastReceiveTime: null
        };
        
        console.log('蓝牙连接已断开');
        
        if (this.onConnectionChange) {
            this.onConnectionChange(false, '');
        }
    }
    
    /**
     * 发送数据到设备
     * @param {string} data - 要发送的数据
     */
    async sendData(data) {
        if (!this.isConnected || !this.txCharacteristic) {
            throw new Error('设备未连接');
        }
        
        try {
            // 将字符串转换为UTF-8字节数组
            const encoder = new TextEncoder();
            const dataBytes = encoder.encode(data + '\n'); // 添加换行符作为消息结束标志
            
            // 使用动态计算的分片大小
            const chunkSize = this.maxChunkSize;
            
            console.log('发送数据:', {
                data: data,
                totalBytes: dataBytes.length,
                chunkSize: chunkSize,
                chunks: Math.ceil(dataBytes.length / chunkSize)
            });
            
            // 分片发送
            for (let i = 0; i < dataBytes.length; i += chunkSize) {
                const chunk = dataBytes.slice(i, i + chunkSize);
                await this.txCharacteristic.writeValue(chunk);
                
                console.log(`发送分片 ${Math.floor(i/chunkSize) + 1}/${Math.ceil(dataBytes.length/chunkSize)}:`, {
                    chunkSize: chunk.length,
                    offset: i
                });
                
                // 添加小延迟确保数据传输稳定
                if (i + chunkSize < dataBytes.length) {
                    await this.delay(10);
                }
            }
            
            console.log('数据发送成功:', data);
            
        } catch (error) {
            console.error('发送数据失败:', error);
            throw error;
        }
    }
    
    /**
     * 处理接收到的数据
     * @param {Event} event - 特征值变化事件
     */
    handleDataReceived(event) {
        try {
            const value = event.target.value;
            // console.log('原始数据:', value);
            const uint8Array = new Uint8Array(value.buffer);
            
            // 更新调试信息
            this.receiveCount++;
            this.lastReceiveTime = new Date();
            
            // 更新接收统计
            this.characteristicsInfo.receiveCount++;
            this.characteristicsInfo.totalBytes += value.byteLength;
            this.characteristicsInfo.lastReceiveTime = new Date();
            
            // 详细日志
            console.log('原始数据接收:', {
                count: this.receiveCount,
                length: value.byteLength,
                hex: Array.from(uint8Array).map(b => b.toString(16).padStart(2, '0')).join(' '),
                timestamp: this.lastReceiveTime.toLocaleTimeString()
            });
            
            // 检查是否是文件数据（以0x00开头）
            console.log('第一个字节:', uint8Array[0]);
            if (uint8Array.length > 0 && uint8Array[0] === 0x00) {
                console.log('检测到文件数据');
                this.handleFileData(uint8Array);
                
                // 同时通知上层应用接收到文件数据
                if (this.onDataReceived) {
                    this.onDataReceived(uint8Array); // 传递原始字节数组
                }
            } else {
                // 普通文本数据处理
                const decoder = new TextDecoder();
                const chunk = decoder.decode(value);
                
                console.log('文本数据:', chunk);
                
                // 将接收到的数据添加到缓冲区
                this.receiveBuffer += chunk;
                
                console.log('缓冲区状态:', {
                    bufferLength: this.receiveBuffer.length,
                    bufferContent: this.receiveBuffer.replace(/\r/g, '\\r').replace(/\n/g, '\\n')
                });
                
                // 处理缓冲区中的完整消息
                this.processBufferedMessages();
            }
            
        } catch (error) {
            console.error('处理接收数据时出错:', error);
            if (this.onError) {
                this.onError(error);
            }
        }
    }
    
    /**
     * 处理缓冲区中的完整消息
     * 支持\n和\r\n两种结尾符
     */
    processBufferedMessages() {
        try {
            // 查找消息结尾符（\n或\r\n）
            let messageEndIndex = -1;
            let endMarker = '';
            
            // 优先查找\r\n
            const crlfIndex = this.receiveBuffer.indexOf('\r\n');
            const lfIndex = this.receiveBuffer.indexOf('\n');
            
            if (crlfIndex !== -1 && (lfIndex === -1 || crlfIndex <= lfIndex)) {
                messageEndIndex = crlfIndex;
                endMarker = '\r\n';
            } else if (lfIndex !== -1) {
                messageEndIndex = lfIndex;
                endMarker = '\n';
            }
            
            // 如果找到完整消息
            if (messageEndIndex !== -1) {
                // 提取完整消息
                const message = this.receiveBuffer.substring(0, messageEndIndex).trim();
                
                // 从缓冲区中移除已处理的消息
                this.receiveBuffer = this.receiveBuffer.substring(messageEndIndex + endMarker.length);
                
                console.log('提取完整消息:', {
                    message: message,
                    endMarker: endMarker.replace(/\r/g, '\\r').replace(/\n/g, '\\n'),
                    remainingBuffer: this.receiveBuffer.replace(/\r/g, '\\r').replace(/\n/g, '\\n')
                });
                
                // 处理完整消息
                if (message.length > 0) {
                    console.log('处理完整消息:', message);
                    
                    // 调用数据接收回调
                    if (this.onDataReceived) {
                        console.log('调用onDataReceived回调:', message);
                        this.onDataReceived(message);
                    } else {
                        console.warn('onDataReceived回调未设置');
                    }
                }
                
                // 递归处理缓冲区中的其他消息
                if (this.receiveBuffer.length > 0) {
                    this.processBufferedMessages();
                }
            }
            
        } catch (error) {
            console.error('处理缓冲区消息时出错:', error);
        }
    }
    
    /**
     * 处理文件数据（以0x00开头）
     * @param {Uint8Array} data 接收到的数据
     */
    handleFileData(data) {
        try {
            let fileData = data;
            
            // 如果第一个字节是0x00标识符，则跳过
            if (data.length > 0 && data[0] === 0x00) {
                fileData = data.slice(1);
            }
            
            console.log('文件数据块:', {
                length: fileData.length,
                hex: Array.from(fileData.slice(0, Math.min(32, fileData.length))).map(b => b.toString(16).padStart(2, '0')).join(' ') + (fileData.length > 32 ? '...' : '')
            });
            
            // 将文件数据添加到文件缓冲区
            const newBuffer = new Uint8Array(this.fileReceiveBuffer.length + fileData.length);
            newBuffer.set(this.fileReceiveBuffer);
            newBuffer.set(fileData, this.fileReceiveBuffer.length);
            this.fileReceiveBuffer = newBuffer;
            
            console.log('文件缓冲区状态:', {
                totalLength: this.fileReceiveBuffer.length,
                fileName: this.currentFileName
            });
            
            // 调用文件数据接收回调
            if (this.onFileDataReceived) {
                this.onFileDataReceived({
                    fileName: this.currentFileName,
                    data: fileData,
                    totalLength: this.fileReceiveBuffer.length
                });
            }
            
        } catch (error) {
            console.error('处理文件数据时出错:', error);
            if (this.onError) {
                this.onError(error);
            }
        }
    }
    
    /**
     * 开始文件接收
     * @param {string} fileName 文件名
     */
    startFileReceive(fileName) {
        console.log('开始接收文件:', fileName);
        this.isReceivingFile = true;
        this.currentFileName = fileName;
        this.fileReceiveBuffer = new Uint8Array(0);
    }
    
    /**
     * 结束文件接收并返回文件数据
     * @returns {Object} 包含文件名和数据的对象
     */
    endFileReceive() {
        console.log('结束文件接收:', {
            fileName: this.currentFileName,
            totalBytes: this.fileReceiveBuffer.length
        });
        
        const result = {
            fileName: this.currentFileName,
            data: this.fileReceiveBuffer,
            size: this.fileReceiveBuffer.length
        };
        
        // 重置状态
        this.isReceivingFile = false;
        this.currentFileName = '';
        this.fileReceiveBuffer = new Uint8Array(0);
        
        return result;
    }
    
    /**
     * 获取当前文件接收状态
     * @returns {Object} 文件接收状态信息
     */
    getFileReceiveStatus() {
        return {
            isReceiving: this.isReceivingFile,
            fileName: this.currentFileName,
            bytesReceived: this.fileReceiveBuffer.length
        };
    }
    
    /**
     * 动态发现和识别特征值
     */
    async discoverCharacteristics() {
        try {
            // 获取服务下的所有特征
            const characteristics = await this.service.getCharacteristics();
            console.log(`发现 ${characteristics.length} 个特征:`);
            
            let txCharacteristic = null;
            let rxCharacteristic = null;
            
            // 遍历特征，根据属性识别TX和RX
            for (const characteristic of characteristics) {
                const properties = characteristic.properties;
                console.log(`特征 ${characteristic.uuid}:`, {
                    write: properties.write,
                    writeWithoutResponse: properties.writeWithoutResponse,
                    notify: properties.notify,
                    indicate: properties.indicate,
                    read: properties.read
                });
                
                // TX特征：具有写入属性
                if ((properties.write || properties.writeWithoutResponse) && !txCharacteristic) {
                    txCharacteristic = characteristic;
                    console.log(`识别为TX特征: ${characteristic.uuid}`);
                }
                
                // RX特征：具有通知属性
                if ((properties.notify || properties.indicate) && !rxCharacteristic) {
                    rxCharacteristic = characteristic;
                    console.log(`识别为RX特征: ${characteristic.uuid}`);
                }
            }
            
            // 检查是否找到了必要的特征
            if (!txCharacteristic) {
                throw new Error('未找到可写入的TX特征');
            }
            
            if (!rxCharacteristic) {
                throw new Error('未找到可通知的RX特征');
            }
            
            // 分配特征
            this.txCharacteristic = txCharacteristic;
            this.rxCharacteristic = rxCharacteristic;
            
            // 更新特征值信息
            this.characteristicsInfo.tx = {
                uuid: txCharacteristic.uuid,
                properties: txCharacteristic.properties
            };
            this.characteristicsInfo.rx = {
                uuid: rxCharacteristic.uuid,
                properties: rxCharacteristic.properties
            };
            
            // 保存特征详细信息
            this.characteristicsDetails = {
                tx: {
                    uuid: txCharacteristic.uuid,
                    properties: txCharacteristic.properties
                },
                rx: {
                    uuid: rxCharacteristic.uuid,
                    properties: rxCharacteristic.properties
                },
                allCharacteristics: characteristics.map(char => ({
                    uuid: char.uuid,
                    properties: char.properties
                }))
            };
            
            console.log('特征识别完成:', {
                tx: this.txCharacteristic.uuid,
                rx: this.rxCharacteristic.uuid,
                details: this.characteristicsDetails
            });
            
        } catch (error) {
            console.error('特征发现失败:', error);
            throw error;
        }
    }

    /**
     * 延迟函数
     * @param {number} ms - 延迟毫秒数
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
    
    /**
     * 获取当前连接的MTU值
     */
    async getMTU() {
        if (!this.server || !this.server.connected) {
            console.warn('设备未连接，无法获取MTU');
            return this.mtu;
        }
        
        try {
            // 尝试获取MTU（如果浏览器支持）
            if (this.server.getMTU) {
                const mtu = await this.server.getMTU();
                console.log('获取到MTU值:', mtu);
                return mtu;
            } else {
                console.log('浏览器不支持getMTU，使用默认值');
                return this.mtu;
            }
        } catch (error) {
            console.warn('获取MTU失败:', error);
            return this.mtu;
        }
    }
    
    /**
     * 协商并设置最优MTU
     */
    async negotiateMTU() {
        try {
            // 获取当前MTU
            const currentMTU = await this.getMTU();
            this.mtu = currentMTU;
            
            // 计算最大分片大小
            // MTU包含ATT头部(3字节)，所以实际可用大小是MTU-3
            this.maxChunkSize = Math.max(this.mtu - 3, 240);
            this.mtuNegotiated = true;
            
            console.log('MTU协商完成:', {
                mtu: this.mtu,
                maxChunkSize: this.maxChunkSize
            });
            
            return {
                mtu: this.mtu,
                maxChunkSize: this.maxChunkSize
            };
        } catch (error) {
            console.error('MTU协商失败:', error);
            // 使用默认值
            this.maxChunkSize = 20;
            return {
                mtu: this.mtu,
                maxChunkSize: this.maxChunkSize
            };
        }
    }
    
    /**
     * 重新协商MTU
     */
    async renegotiateMTU() {
        if (!this.isConnected) {
            throw new Error('设备未连接');
        }
        
        try {
            console.log('重新协商MTU...');
            const result = await this.negotiateMTU();
            console.log('MTU重新协商完成:', result);
            return result;
        } catch (error) {
            console.error('MTU重新协商失败:', error);
            throw error;
        }
    }
    
    /**
     * 获取连接状态
     */
    getConnectionStatus() {
        return {
            isConnected: this.isConnected,
            deviceName: this.device ? this.device.name : '',
            deviceId: this.device ? this.device.id : ''
        };
    }
    
    /**
     * 检查设备是否已连接
     */
    isConnected() {
        return this.device && this.device.gatt && this.device.gatt.connected;
    }
    
    /**
     * 获取特征值信息
     */
    getCharacteristicsInfo() {
        return this.characteristicsInfo;
    }
    
    /**
     * 重新连接
     */
    async reconnect() {
        if (this.device) {
            try {
                console.log('尝试重新连接...');
                await this.disconnect();
                await this.delay(1000);
                
                // 重新连接到已配对的设备
                this.server = await this.device.gatt.connect();
                this.service = await this.server.getPrimaryService(this.SERVICE_UUID);
                await this.discoverCharacteristics();
                
                await this.rxCharacteristic.startNotifications();
                this.rxCharacteristic.addEventListener('characteristicvaluechanged', (event) => {
                    this.handleDataReceived(event);
                });
                
                this.isConnected = true;
                console.log('重新连接成功!');
                
                if (this.onConnectionChange) {
                    this.onConnectionChange(true, this.device.name);
                }
                
            } catch (error) {
                console.error('重新连接失败:', error);
                this.handleDisconnection();
                throw error;
            }
        } else {
            throw new Error('没有可重连的设备');
        }
    }
    
    /**
     * 清除接收缓冲区和统计
     */
    clearReceiveBuffer() {
        this.receiveBuffer = '';
        this.receiveCount = 0;
        this.characteristicsInfo.receiveCount = 0;
        this.characteristicsInfo.totalBytes = 0;
        this.characteristicsInfo.lastReceiveTime = null;
        console.log('接收缓冲区和统计已清除');
    }
    
    /**
     * 获取特征值信息
     */
    getCharacteristicsInfo() {
        if (!this.characteristicsDetails) {
            return null;
        }
        
        return {
            tx: this.characteristicsDetails.tx,
            rx: this.characteristicsDetails.rx,
            notificationsEnabled: this.rxCharacteristic ? true : false,
            receiveBufferLength: this.receiveBuffer.length,
            receiveCount: this.receiveCount,
            lastReceiveTime: this.lastReceiveTime,
            allCharacteristics: this.characteristicsDetails.allCharacteristics,
            // 添加MTU信息
            mtu: this.mtu,
            maxChunkSize: this.maxChunkSize,
            mtuNegotiated: this.mtuNegotiated
        };
    }
    
    /**
     * 重新启用通知
     */
    async restartNotifications() {
        if (!this.rxCharacteristic || !this.isConnected) {
            throw new Error('设备未连接或RX特征值不可用');
        }
        
        try {
            // 停止现有通知
            await this.rxCharacteristic.stopNotifications();
            this.characteristicsInfo.notificationsEnabled = false;
            await this.delay(100);
            
            // 重新启用通知
            await this.rxCharacteristic.startNotifications();
            this.characteristicsInfo.notificationsEnabled = true;
            console.log('通知已重新启用');
            
        } catch (error) {
            console.error('重新启用通知失败:', error);
            throw error;
        }
    }
    
    /**
     * 发送测试命令
     */
    async sendTestCommand() {
        if (!this.isConnected) {
            throw new Error('设备未连接');
        }
        
        try {
            const testCommand = 'BASE_INFO';
            await this.sendData(testCommand);
            console.log('测试命令已发送:', testCommand);
        } catch (error) {
            console.error('发送测试命令失败:', error);
            throw error;
        }
    }
    
    /**
     * 获取调试统计信息
     */
    getDebugStats() {
        return {
            isConnected: this.isConnected,
            deviceName: this.device ? this.device.name : null,
            deviceId: this.device ? this.device.id : null,
            receiveCount: this.receiveCount,
            lastReceiveTime: this.lastReceiveTime,
            receiveBufferLength: this.receiveBuffer.length,
            hasCharacteristics: !!(this.txCharacteristic && this.rxCharacteristic),
            characteristicsCount: this.characteristicsDetails ? this.characteristicsDetails.allCharacteristics.length : 0
        };
    }
}

// 导出类（如果在模块环境中使用）
if (typeof module !== 'undefined' && module.exports) {
    module.exports = BLEManager;
}