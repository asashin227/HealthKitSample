//
//  ViewController.swift
//  HealthKitSample
//
//  Created by Asakura Shinsuke on 2018/03/03.
//  Copyright © 2018年 asashin227. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController {
    // 書き込みタイプ
    let typesToWrite: Set<HKSampleType> = [HKSampleType.quantityType(forIdentifier: .stepCount)!]
    // 読み込みタイプ
    let typesToRead: Set<HKObjectType> = [HKQuantityType.quantityType(forIdentifier: .stepCount)!]
    
    private let healthStore: HKHealthStore? = {
        HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }()
    
    @IBOutlet weak var authButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        requestHealthKitAuthorization {
            print("許可: \($0)")
        }
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

extension ViewController {

    @IBAction func didTaped(executeSampleQueryButton: Any) {
        let now = Date()
        // すべての記録を取得する
        self.executeSampleQuery(type: HKSampleType.quantityType(forIdentifier: .stepCount)!,
                                unit: HKUnit.count(),
                                startDate: now.add(day: -1),
                                endDate: now)
    }
    
    @IBAction func didTaped(collectionQueryButton: Any) {
        let now = Date()
        // 統計データ取得する
        self.executeCollectionQuery(type: HKSampleType.quantityType(forIdentifier: .stepCount)!,
                                    unit: HKUnit.count(),
                                    startDate: now.add(day: -1),
                                    endDate: now)
    }
    
    @IBAction func didTaped(_ SaveExerciseTimeButton: Any) {
        let now = Date()
        self.saveHealthKit(doubleValue: 5,
                                 type: HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                                 unit: HKUnit.count(),
                                 startDate: now.add(minute: -5),
                                 endDate: now)
    }
}


extension ViewController {
    
    /// HealthKitへのアクセスを求める
    ///
    /// - Parameter completion: 終了後処理
    func requestHealthKitAuthorization(completion: @escaping (Bool) -> Void) {
        guard let healthStore = healthStore else {
            completion(false)
            return
        }
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, _ in
            completion(success)
        }
    }
    
    /// HealthKitからデータを取得する
    ///
    /// - Parameters:
    ///   - type: 取得対象のタイプ
    ///   - unit: 単位
    ///   - startDate: 取得開始日
    ///   - endDate: 取得終了日
    func executeSampleQuery(type: HKSampleType, unit: HKUnit, startDate: Date, endDate: Date) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate, .strictEndDate])
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 0, sortDescriptors: nil) { _, results, _ in
            guard let results = results else { return }
            
            results.forEach { result in
                if let q = result as? HKQuantitySample {
                    print("startDate: \(q.startDate)")
                    print("endDate: \(q.endDate)")
                    if let device = q.device {
                        print("device: \(device.name!)")
                    }
                    print("value: \(q.quantity.doubleValue(for: unit))")
                    print("---")
                }
            }
            let sum = results.reduce(0) {
                if let q = $1 as? HKQuantitySample {
                    return $0 + Int(q.quantity.doubleValue(for: unit))
                }
                return $0
            }
            print("合計値: \(sum)")
        }
        healthStore!.execute(query)
    }
    
    /// healthkitから統計データを取得する
    ///
    /// - Parameters:
    ///   - type: 取得対象のタイプ
    ///   - unit: 単位
    ///   - startDate: 取得開始日
    ///   - endDate: 取得終了日
    func executeCollectionQuery(type: HKQuantityType, unit: HKUnit, startDate: Date, endDate: Date) {
        var components = DateComponents()
        components.day = 1
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate, .strictEndDate])
        let collectionQuerty = HKStatisticsCollectionQuery(quantityType: type,
                                                           quantitySamplePredicate: predicate,
                                                           options: .cumulativeSum,
                                                           anchorDate: startDate,
                                                           intervalComponents: components)
        collectionQuerty.initialResultsHandler = {  _, results, _ in
            guard let results = results else { return }
            
            results.enumerateStatistics(from: startDate, to: endDate) { result, _ in
                if let q = result.sumQuantity() {
                    print("startDate: \(result.startDate)")
                    print("endDate: \(result.endDate)")
                    print("value: \(q.doubleValue(for: unit))")
                }
            }
        }
        healthStore!.execute(collectionQuerty)
    }
    
    
    /// HealthKitへ保存します
    ///
    /// - Parameters:
    ///   - doubleValue: 値
    ///   - type: タイプ
    ///   - unit: 単位
    ///   - startDate: 開始日
    ///   - endDate: 終了日
    func saveHealthKit(doubleValue: Double, type: HKQuantityType, unit: HKUnit, startDate: Date, endDate: Date) {
        let quantity = HKQuantity(unit: unit, doubleValue: doubleValue)
        let obj = HKQuantitySample(type: type, quantity: quantity, start: startDate, end: endDate)
        healthStore!.save(obj, withCompletion: { success, error in
            print("result: \(success)")
            if let error = error {
                print("error: \(error.localizedDescription)")
            }
        })
    }
}

private extension Date {
    
    func add(year: Int = 0, month: Int = 0, day: Int = 0, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
        
        let formatter = DateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "ja_JP") as Locale
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var components = DateComponents()
        
        components.setValue(year,for: Calendar.Component.year)
        components.setValue(month,for: Calendar.Component.month)
        components.setValue(day,for: Calendar.Component.day)
        components.setValue(hour,for: Calendar.Component.hour)
        components.setValue(minute,for: Calendar.Component.minute)
        components.setValue(second,for: Calendar.Component.second)
        
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        
        return calendar.date(byAdding: components, to: self)!
    }
}

