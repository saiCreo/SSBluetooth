//
//  ViewController.swift
//  SSBluetooth
//
//  Created by Sai Sandeep on 28/02/20.
//  Copyright © 2020 Sai Sandeep. All rights reserved.
//

import UIKit
import CoreBluetooth
import os

class ViewController: UIViewController {
    
    let serviceUUID = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    
    var stringFromData: String? = nil
    
    var services = [CBService]()
    
    var characteristics = [CBCharacteristic]()
    
    var centralManager: CBCentralManager!
    
    var discoveredPeripherals = [CBPeripheral]()
    
    var selectedPeripheral: CBPeripheral? = nil
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    @objc func rightBarButtonTapped(sender: UIBarButtonItem) {
        if selectedPeripheral?.state == .connected {
            self.cleanup()
            services.removeAll()
            characteristics.removeAll()
            self.tableView.reloadData()
            centralManager.scanForPeripherals(withServices: nil,
                                              options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            self.navigationItem.rightBarButtonItem = nil
            self.navigationItem.leftBarButtonItem = nil
        }
    }
    
    @objc func leftBarButtonTapped(sender: UIBarButtonItem) {
        let msgData = "Message from iphone".data(using: .utf8)!
        
       
//        let stringFromData = String(data: msgData, encoding: .utf8)
//        os_log("Writing %d bytes: %s", bytesToCopy, String(describing: stringFromData))
        
        selectedPeripheral!.writeValue(msgData, for: characteristics.last!, type: .withResponse)
        selectedPeripheral!.setNotifyValue(false, for: characteristics.last!)
    }
    
    private func cleanup() {
        // Don't do anything if we're not connected
        guard let selectedPeripheral = selectedPeripheral,
            case .connected = selectedPeripheral.state else { return }
        
        for service in (selectedPeripheral.services ?? [] as [CBService]) {
            for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
                if characteristic.isNotifying {
                    // It is notifying, so unsubscribe
                    self.selectedPeripheral?.setNotifyValue(false, for: characteristic)
                }
            }
        }
        
        // If we've gotten this far, we're connected, but we're not subscribed, so we just disconnect
        centralManager.cancelPeripheralConnection(selectedPeripheral)
    }
    
    private func retrievePeripheral() {
        
        let connectedPeripherals: [CBPeripheral] = (centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID]))
        
        os_log("Found connected Peripherals with transfer service: %@", connectedPeripherals)
        
        if let connectedPeripheral = connectedPeripherals.last {
            os_log("Connecting to peripheral %@", connectedPeripheral)
            self.selectedPeripheral = connectedPeripheral
            centralManager.connect(connectedPeripheral, options: nil)
        } else {
            // We were not connected to our counterpart, so start scanning
            centralManager.scanForPeripherals(withServices: nil,
                                              options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            //            centralManager.scanForPeripherals(withServices: [TransferService.serviceUUID],
            //                                               options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }
    
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if selectedPeripheral?.state == .connected {
            return 1
        }else {
            return discoveredPeripherals.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        if selectedPeripheral?.state == .connected {
            cell?.textLabel?.numberOfLines = 0
            cell?.textLabel?.text = "From Raspberrypi: \(stringFromData ?? "0")"
            cell?.detailTextLabel?.numberOfLines = 0
            cell?.detailTextLabel?.text = "\n\nService UUID:\n" + services.map({$0.uuid.uuidString}).joined(separator: ", ")  + "\n\nCharacteristics UUID:\n" + characteristics.map({$0.uuid.uuidString}).joined(separator: ", ")
            
        }else {
            cell?.textLabel?.text = discoveredPeripherals[indexPath.row].name ?? "NA"
            cell?.detailTextLabel?.text = discoveredPeripherals[indexPath.row].identifier.uuidString
        }
        return cell!
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedPeripheral = discoveredPeripherals[indexPath.row]
        centralManager.connect(discoveredPeripherals[indexPath.row], options: nil)
    }
}

extension ViewController: CBCentralManagerDelegate {
    // implementations of the CBCentralManagerDelegate methods
    
    /*
     *  centralManagerDidUpdateState is a required protocol method.
     *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
     *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
     *  the Central is ready to be used.
     */
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .poweredOn:
            // ... so start working with the peripheral
            os_log("CBManager is powered on")
            //            retrievePeripheral()
            retrievePeripheral()
        case .poweredOff:
            os_log("CBManager is not powered on")
            // In a real app, you'd deal with all the states accordingly
            return
        case .resetting:
            os_log("CBManager is resetting")
            // In a real app, you'd deal with all the states accordingly
            return
        case .unauthorized:
            // In a real app, you'd deal with all the states accordingly
            if #available(iOS 13.0, *) {
                switch central.authorization {
                case .denied:
                    os_log("You are not authorized to use Bluetooth")
                case .restricted:
                    os_log("Bluetooth is restricted")
                default:
                    os_log("Unexpected authorization")
                }
            } else {
                // Fallback on earlier versions
            }
            return
        case .unknown:
            os_log("CBManager state is unknown")
            // In a real app, you'd deal with all the states accordingly
            return
        case .unsupported:
            os_log("Bluetooth is not supported on this device")
            // In a real app, you'd deal with all the states accordingly
            return
        @unknown default:
            os_log("A previously unknown central manager state occurred")
            // In a real app, you'd deal with yet unknown cases that might occur in the future
            return
        }
    }
    
    /*
     *  This callback comes whenever a peripheral that is advertising the transfer serviceUUID is discovered.
     *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
     *  we start the connection process
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        // Reject if the signal strength is too low to attempt data transfer.
        // Change the minimum RSSI value depending on your app’s use case.
        if let index = discoveredPeripherals.firstIndex(where: {$0.identifier == peripheral.identifier}) {
            discoveredPeripherals[index] = peripheral
        }else {
            discoveredPeripherals.append(peripheral)
        }
        self.tableView.reloadData()
        guard RSSI.intValue >= -100
            else {
                print(peripheral,selectedPeripheral)
                os_log("Discovered perhiperal not in expected range, at %d", RSSI.intValue)
                return
        }
        
        os_log("Discovered %s at %d", String(describing: peripheral.name), RSSI.intValue)
        
        // Device is in range - have we already seen it?
        //        if discoveredPeripheral != peripheral {
        //
        //            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it.
        //            discoveredPeripheral = peripheral
        //
        //            // And finally, connect to the peripheral.
        //            os_log("Connecting to perhiperal %@", peripheral)
        //            centralManager.connect(peripheral, options: nil)
        //        }
    }
    
    /*
     *  If the connection fails for whatever reason, we need to deal with it.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        os_log("Failed to connect to %@. %s", peripheral, String(describing: error))
        //        cleanup()
    }
    
    /*
     *  We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Peripheral Connected")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Disconnect", style: .plain, target: self, action: #selector(rightBarButtonTapped(sender:)))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Send", style: .plain, target: self, action: #selector(leftBarButtonTapped(sender:)))
        self.tableView.reloadData()
        // Stop scanning
        centralManager.stopScan()
        os_log("Scanning stopped")
        
        // set iteration info
        //        connectionIterationsComplete += 1
        //        writeIterationsComplete = 0
        //
        //        // Clear the data that we may already have
        //        data.removeAll(keepingCapacity: false)
        
        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only for services that match our UUID
        peripheral.discoverServices(nil)
    }
    
    /*
     *  Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        os_log("Perhiperal Disconnected")
        //        discoveredPeripheral = nil
        //
        //        // We're disconnected, so start scanning again
        //        if connectionIterationsComplete < defaultIterations {
        //            retrievePeripheral()
        //        } else {
        //            os_log("Connection iterations completed")
        //        }
    }
    
}


extension ViewController: CBPeripheralDelegate {
    // implementations of the CBPeripheralDelegate methods
    
    /*
     *  The peripheral letting us know when services have been invalidated.
     */
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        //        for service in invalidatedServices where service.uuid == TransferService.serviceUUID {
        //            os_log("Transfer service is invalidated - rediscover services")
        //            peripheral.discoverServices([TransferService.serviceUUID])
        //        }
    }
    
    /*
     *  The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print(peripheral.services)
        //        if let error = error {
        //            os_log("Error discovering services: %s", error.localizedDescription)
        //            cleanup()
        //            return
        //        }
        //
        //        // Discover the characteristic we want...
        //
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        guard let peripheralServices = peripheral.services else { return }
        services = peripheralServices
        for service in peripheralServices {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    /*
     *  The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any).
        //        if let error = error {
        //            os_log("Error discovering characteristics: %s", error.localizedDescription)
        //            cleanup()
        //            return
        //        }
        // Again, we loop through the array, just in case and check if it's the right one
        guard let serviceCharacteristics = service.characteristics else { return }
        characteristics = serviceCharacteristics
        for characteristic in serviceCharacteristics {
            // If it is, subscribe to it
            //            transferCharacteristic = characteristic
            print(characteristic.uuid.uuidString)
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    /*
     *   This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            os_log("Error discovering characteristics: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        guard let characteristicData = characteristic.value,
            let stringFromData = String(data: characteristicData, encoding: .utf8) else { return }
        self.stringFromData = stringFromData
        os_log("Received %s %d bytes: %s", characteristic.uuid.uuidString, characteristicData.count, stringFromData)
        self.tableView.reloadData()
        //        // Have we received the end-of-message token?
        //        if stringFromData == "EOM" {
        //            // End-of-message case: show the data.
        //            // Dispatch the text view update to the main queue for updating the UI, because
        //            // we don't know which thread this method will be called back on.
        //            DispatchQueue.main.async() {
        //                self.textView.text = String(data: self.data, encoding: .utf8)
        //            }
        //
        //            // Write test data
        ////            writeData()
        //        } else {
        //            // Otherwise, just append the data to what we have previously received.
        //            data.append(characteristicData)
        //        }
    }
    
    //    /*
    //     *  The peripheral letting us know whether our subscribe/unsubscribe happened or not
    //     */
    //    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
    //        // Deal with errors (if any)
    //        if let error = error {
    //            os_log("Error changing notification state: %s", error.localizedDescription)
    //            return
    //        }
    //
    //        // Exit if it's not the transfer characteristic
    //        guard characteristic.uuid == TransferService.characteristicUUID else { return }
    //
    //        if characteristic.isNotifying {
    //            // Notification has started
    //            os_log("Notification began on %@", characteristic)
    //        } else {
    //            // Notification has stopped, so disconnect from the peripheral
    //            os_log("Notification stopped on %@. Disconnecting", characteristic)
    //            cleanup()
    //        }
    //
    //    }
    //
    //    /*
    //     *  This is called when peripheral is ready to accept more data when using write without response
    //     */
    //    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
    //        os_log("Peripheral is ready, send data")
    ////        writeData()
    //    }
    //
}
