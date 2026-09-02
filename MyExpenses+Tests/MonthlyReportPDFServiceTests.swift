//
//  MonthlyReportPDFServiceTests.swift
//  MyExpenses+Tests
//

import Foundation
import PDFKit
import Testing
@testable import MyExpenses_

@MainActor
struct MonthlyReportPDFServiceTests {

    @Test func rendersASinglePageWithBothBreakdowns() {
        let categoryTotals = [
            CategorySpending(category: nil, total: 200),
            CategorySpending(category: nil, total: 120),
            CategorySpending(category: nil, total: 60),
        ]
        let incomeSourceTotals = [
            IncomeSourceTotal(source: .salary, total: 1000),
            IncomeSourceTotal(source: .business, total: 500),
            IncomeSourceTotal(source: .stocks, total: 300),
        ]

        let url = MonthlyReportPDFService.export(
            month: Date(),
            incomeTotal: 1800,
            expenseTotal: 380,
            categoryTotals: categoryTotals,
            incomeSourceTotals: incomeSourceTotals,
            currencyCode: "AED"
        )

        #expect(url != nil)
        guard let url else { return }
        let document = PDFDocument(url: url)
        #expect(document != nil)
        #expect(document?.pageCount == 1)

        // The page height is sized to fit both breakdown sections rather than
        // clipping at a fixed US-Letter height.
        if let page = document?.page(at: 0) {
            #expect(page.bounds(for: .mediaBox).height > 400)
        }

        try? FileManager.default.removeItem(at: url)
    }

    @Test func rendersWhenBothBreakdownsAreEmpty() {
        let url = MonthlyReportPDFService.export(
            month: Date(),
            incomeTotal: 0,
            expenseTotal: 0,
            categoryTotals: [],
            incomeSourceTotals: [],
            currencyCode: "AED"
        )

        #expect(url != nil)
        guard let url else { return }
        let document = PDFDocument(url: url)
        #expect(document?.pageCount == 1)

        try? FileManager.default.removeItem(at: url)
    }
}
