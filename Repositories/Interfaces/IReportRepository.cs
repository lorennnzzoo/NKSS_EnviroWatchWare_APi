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
        DataTable GetRawChannelDataAsDataTable(List<int> channelIds, DateTime From, DateTime To);
        DataTable GetAvgChannelDataAsDataTable(List<int> channelIds, DateTime from, DateTime to, int interval);
    }
}
