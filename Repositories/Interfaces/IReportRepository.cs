using Models.Report;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories.Interfaces
{
    public interface IReportRepository
    {
        DataTable GetRawDataReport(List<int> channelIds, DateTime From, DateTime To);
        DataTable GetAverageDataReport(List<int> channelIds, DateTime From, DateTime To, int IntervalInMinutes);
        DataTable GetRawExceedanceReport(List<int> channelIds, DateTime From, DateTime To);
        DataTable GetAverageExceedanceReport(List<int> channelIds, DateTime From, DateTime To, int IntervalInMinutes);
        DataTable GetAvailabilityReport(List<int> channelIds, DateTime From, DateTime To);
    }
}
