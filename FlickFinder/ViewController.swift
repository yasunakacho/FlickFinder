//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        subscribeToNotification(UIKeyboardWillShowNotification, selector: Constants.Selectors.KeyboardWillShow)
        subscribeToNotification(UIKeyboardWillHideNotification, selector: Constants.Selectors.KeyboardWillHide)
        subscribeToNotification(UIKeyboardDidShowNotification, selector: Constants.Selectors.KeyboardDidShow)
        subscribeToNotification(UIKeyboardDidHideNotification, selector: Constants.Selectors.KeyboardDidHide)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String!] = [
                Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.Text: phraseTextField.text,
                Constants.FlickrParameterKeys.GalleryID: Constants.FlickrParameterValues.GalleryID,
                Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
            ]
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String!] = [
                Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.BoundingBox: bboxString(),
                Constants.FlickrParameterKeys.GalleryID: Constants.FlickrParameterValues.GalleryID,
                Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
            ]
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    private func bboxString() ->String {
        if let latitude = Double(latitudeTextField.text!), let longitude = Double(longitudeTextField.text!) {
            let minimumLon = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
            let minimumLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
            let maximumLon = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
            let maximumLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
            return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
        } else {
            return "0,0,0,0"
        }
    }
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(methodParameters: [String:AnyObject]) {
 
        // TODO: Make request to Flickr!
        let session = NSURLSession.sharedSession()
        let request = NSURLRequest(URL: flickrURLFromParameters(methodParameters))
        
        let task = session.dataTaskWithRequest(request){ (data, response, error) in
            
            // if an error occurs, print it and re-enable the UI
            func displayError(error: String){
            print(error)
                performUIUpdatesOnMain{
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "Now photo returned. Try again."
                    self.photoImageView.image = nil
                }
            }
            
            // GUARD: Was there an error?
            guard (error == nil) else {
                displayError("There was an error with your request:\(error)")
                return
            }
            
            // GUARD: Did we get a successfull 2xx response?
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where
                statusCode >= 200 && statusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx!")
                return
            }
            
            // GUARD: Was there any data returned?
            guard let data = data else {
                displayError("No data was returned by the request!")
                return
            }
            
            //parse the data
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                displayError("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            //GUARD: Did Flickr return an error?
            guard let stat = parsedResult [Constants.FlickrResponseKeys.Status] as?
                String where stat == Constants.FlickrResponseValues.OKStatus else {
                displayError("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            //GUARD: Is the "photos" key in our result?
            guard let photoDictionary = parsedResult [Constants.FlickrResponseKeys.Photos] as? [String: AnyObject] else {
                displayError("Cannot find key '\(Constants.FlickrResponseKeys.Photos) in \(parsedResult)'")
                return
            }
            
            //CHECK if we have a page number or not
            guard let totalPages = photoDictionary[Constants.FlickrResponseKeys.Pages] as? Int else {
                displayError("Cannot find key '\(Constants.FlickrResponseKeys.Pages)' in \(photoDictionary)")
                return
            }
            
            let pageLimit = min(totalPages, 40)
            let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
            self.displayImageFromFlickrBySearch(methodParameters, withPageNumber: randomPage)
            }
        task.resume()
    }
    
    private func displayImageFromFlickrBySearch(var methodParameters: [String:AnyObject], withPageNumber: Int) {
        
        methodParameters[Constants.FlickrParameterKeys.Page] = withPageNumber
        
        // TODO: Make request to Flickr!
        let session = NSURLSession.sharedSession()
        let request = NSURLRequest(URL: flickrURLFromParameters(methodParameters))
        
        let task = session.dataTaskWithRequest(request){ (data, response, error) in
            
            // if an error occurs, print it and re-enable the UI
            func displayError(error: String){
                print(error)
                performUIUpdatesOnMain{
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "Now photo returned. Try again."
                    self.photoImageView.image = nil
                }
            }
            
            // GUARD: Was there an error?
            guard (error == nil) else {
                displayError("There was an error with your request:\(error)")
                return
            }
            
            // GUARD: Did we get a successfull 2xx response?
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where
                statusCode >= 200 && statusCode <= 299 else {
                    displayError("Your request returned a status code other than 2xx!")
                    return
            }
            
            // GUARD: Was there any data returned?
            guard let data = data else {
                displayError("No data was returned by the request!")
                return
            }
            
            //parse the data
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                displayError("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            //GUARD: Did Flickr return an error?
            guard let stat = parsedResult [Constants.FlickrResponseKeys.Status] as?
                String where stat == Constants.FlickrResponseValues.OKStatus else {
                    displayError("Flickr API returned an error. See error code and message in \(parsedResult)")
                    return
            }
            
            //GUARD: Is the "photos" key in our result?
            guard let photoDictionary = parsedResult [Constants.FlickrResponseKeys.Photos] as? [String: AnyObject] else {
                displayError("Cannot find key '\(Constants.FlickrResponseKeys.Photos) in \(parsedResult)'")
                return
            }

            //GUARD: Is the "photo" key in photosDictionary?
            guard let photosArray = photoDictionary[Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                displayError("Cannot find key '\(Constants.FlickrResponseKeys.Photo)' in \(photoDictionary)")
                return
            }
            
            if photosArray.count == 0 {
                displayError("No photos found. Search again.")
                return
            } else {
                let randomPhotoIndex = Int(arc4random_uniform(UInt32(photosArray.count)))
                let photoDictionary  = photosArray[randomPhotoIndex] as [String: AnyObject]
                let photoTitle = photoDictionary[Constants.FlickrResponseKeys.Title] as? String
                
                //GUARD: Does our photo have a key for 'url_m'?
                guard let imageUrlString = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String else {
                    displayError("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in \(photoDictionary)")
                    return
                }
                
                let imageURL = NSURL(string: imageUrlString)
                if let imageData = NSData(contentsOfURL: imageURL!){
                    performUIUpdatesOnMain() {
                        self.photoImageView.image = UIImage (data:imageData)
                        self.photoTitleLabel.text = photoTitle ?? "(Untitled)"
                        self.setUIEnabled(true)
                    }
                } else {
                    displayError("Image does not exist at \(imageURL)")
                }
            }
        }
        task.resume()
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(parameters: [String:AnyObject]) -> NSURL {
        
        let components = NSURLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [NSURLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = NSURLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.URL!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(notification: NSNotification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.CGRectValue().height
    }
    
    private func resignIfFirstResponder(textField: UITextField) {
        if textField.isFirstResponder() {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    private func isTextFieldValid(textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!) where !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    private func isValueInRange(value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

extension ViewController {
    
    private func setUIEnabled(enabled: Bool) {
        photoTitleLabel.enabled = enabled
        phraseTextField.enabled = enabled
        latitudeTextField.enabled = enabled
        longitudeTextField.enabled = enabled
        phraseSearchButton.enabled = enabled
        latLonSearchButton.enabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

extension ViewController {
    
    private func subscribeToNotification(notification: String, selector: Selector) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    private func unsubscribeFromAllNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}