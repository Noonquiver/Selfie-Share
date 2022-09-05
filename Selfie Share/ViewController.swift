//
//  ViewController.swift
//  Selfie Share
//
//  Created by Camilo Hernández Guerrero on 22/08/22.
//

import MultipeerConnectivity
import UIKit

class ViewController: UICollectionViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate, MCNearbyServiceAdvertiserDelegate {
    var images = [UIImage]()
    
    var peerID = MCPeerID(displayName: UIDevice.current.name)
    var mcSession: MCSession?
    var mcNearbyServiceAdvertiser: MCNearbyServiceAdvertiser?
    
    var textMessage = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Selfie Share"
        
        let connection = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showConnectionPrompt))
        let imageSender = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(importPicture))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        let texter = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(sendText))
        let connectedPeers = UIBarButtonItem(title: "Who's connected?", style: .plain, target: self, action: #selector(viewConnectedPeers))
        toolbarItems = [connection, spacer, imageSender, spacer, texter, spacer, connectedPeers]
        navigationController?.isToolbarHidden = false

        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession?.delegate = self
    }
    
    func startHosting(action: UIAlertAction) {
        mcNearbyServiceAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: "selfie-share")
        mcNearbyServiceAdvertiser?.delegate = self
        mcNearbyServiceAdvertiser?.startAdvertisingPeer()
    }
    
    func joinSession(action: UIAlertAction) {
        guard let mcSession = mcSession else { return }
        let mcBrowser = MCBrowserViewController(serviceType: "selfie-share", session: mcSession)
        
        mcBrowser.delegate = self
        present(mcBrowser, animated: true)
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageView", for: indexPath)
        
        if let imageView = cell.viewWithTag(1000) as? UIImageView {
            imageView.image = images[indexPath.item]
        }
        
        return cell
    }
    
    @objc func importPicture() {
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc func sendText() {
        guard let mcSession = mcSession else { return }
        
        let alertController = UIAlertController(title: "Send messages!", message: "Type the message you want to send.", preferredStyle: .alert)
        alertController.addTextField()
        
        let getTextMessage = UIAlertAction(title: "Send", style: .default) {
            [weak self, weak alertController] _ in
            guard let text = alertController?.textFields?[0].text else { return }
            self?.textMessage = text
            
            if mcSession.connectedPeers.count > 0 {
                guard let UTF8String = self?.textMessage.utf8 else { return }
                let textData = Data(UTF8String)
                
                do {
                    try mcSession.send(textData, toPeers: mcSession.connectedPeers, with: .reliable)
                } catch {
                    let alertController = UIAlertController(title: "Send error", message: error.localizedDescription, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "Okay", style: .default))
                    self?.present(alertController, animated: true)
                }
            }
        }
        
        alertController.addAction(getTextMessage)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertController, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.editedImage] as? UIImage else { return }
        dismiss(animated: true)
        
        images.insert(image, at: 0)
        collectionView.reloadData()
        
        guard let mcSession = mcSession else { return }
        
        if mcSession.connectedPeers.count > 0 {
            if let imageData = image.pngData() {
                do {
                    try mcSession.send(imageData, toPeers: mcSession.connectedPeers, with: .reliable)
                } catch {
                    let alertController = UIAlertController(title: "Send error", message: error.localizedDescription, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "Okay", style: .default))
                    present(alertController, animated: true)
                }
            }
        }
    }
    
    @objc func showConnectionPrompt() {
        let alertController = UIAlertController(title: "Connect to others", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Host a session", style: .default, handler: startHosting))
        alertController.addAction(UIAlertAction(title: "Join a session", style: .default, handler: joinSession))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertController, animated: true)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) { dismiss(animated: true) }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) { dismiss(animated: true) }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("Connected: \(peerID.displayName).")
        case .connecting:
            print("Connecting: \(peerID.displayName).")
        case .notConnected:
            DispatchQueue.main.async {
                [weak self] in
                let alertController = UIAlertController(title: "\(peerID.displayName) has disconnected from our network.", message: nil, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: .default))
                self?.present(alertController, animated: true)
            }
        @unknown default:
            print("Unknown state received: \(peerID.displayName).")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            [weak self] in
            if let image = UIImage(data: data) {
                self?.images.insert(image, at: 0)
                self?.collectionView.reloadData()
            } else {
                let textMessage = String(decoding: data, as: UTF8.self)
                let alertController = UIAlertController(title: "You have received a message", message: textMessage, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Respond", style: .default, handler: { _ in
                    self?.sendText()
                }))
                alertController.addAction(UIAlertAction(title: "Dismiss", style: .default))
                self?.present(alertController, animated: true)
            }
        }
    }
    
    @objc func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Invitation Received"

        let ac = UIAlertController(title: appName, message: "'\(peerID.displayName)' wants to connect.", preferredStyle: .alert)
        let declineAction = UIAlertAction(title: "Decline", style: .cancel) {
            [weak self] _ in
            invitationHandler(false, self?.mcSession)
        }
        let acceptAction = UIAlertAction(title: "Accept", style: .default) {
            [weak self] _ in
            invitationHandler(true, self?.mcSession)    
        }
        
        ac.addAction(declineAction)
        ac.addAction(acceptAction)
        
        present(ac, animated: true)
    }
    
    @objc func viewConnectedPeers() {
        guard let session = mcSession else { return }
        let alertController = UIAlertController(title: "Currently connected peers", message: nil, preferredStyle: .actionSheet)
        
        for peer in session.connectedPeers {
            let alertAction = UIAlertAction(title: peer.displayName, style: .default)
            alertAction.isEnabled.toggle()
            alertController.addAction(alertAction)
        }
        
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default))
        present(alertController, animated: true)
    }
}
