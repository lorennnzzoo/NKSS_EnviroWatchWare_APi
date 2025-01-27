

using Models.Report;
using System;
using System.Collections.Generic;
using System.Data;

namespace Services.Interfaces
{
    public interface IReportService
    {
        List<ChannelDataReport> GetReport(Models.Post.Report.ReportFilter filter);
        DataTable GenerateReport(List<int> ChannelIds, Models.Post.Report.ReportType reportType,Models.Post.Report.DataAggregationType dataAggregationType,DateTime From,DateTime To);
        List<ChannelDataReport> TransformDataTableToExceedanceReport(DataTable dataTable);

        List<ChannelDataReport> TransformDataTableToDataReport(DataTable dataTable);






        Models.Report.Selection.SelectionModel GetSelectionModel();
    }
}
