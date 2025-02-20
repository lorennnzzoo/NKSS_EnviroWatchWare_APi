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
        DataTable GetChannelDataAvailabilityReportAsDataTable(List<int> channelIds, DateTime From, DateTime To);
        DataTable GetRawChannelDataReportAsDataTable(List<int> channelIds, DateTime From, DateTime To);

        DataTable GetAvgChannelDataReportAsDataTable(List<int> channelIds, DateTime from, DateTime to, int interval);

        DataTable GetRawChannelDataExceedanceReportAsDataTable(List<int> channelIds, DateTime From, DateTime To);
        DataTable GetAvgChannelDataExceedanceReportAsDataTable(List<int> channelIds, DateTime from, DateTime to, int interval);

        //List<OneHourTrend> GetOneHourTrendForChannel(int ChannelId,DateTime From,DateTime To);
    }
}
