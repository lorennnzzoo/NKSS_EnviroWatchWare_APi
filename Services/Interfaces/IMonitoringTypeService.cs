using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Services.Interfaces
{
    public interface IMonitoringTypeService
    {
        IEnumerable<MonitoringType> GetAllMonitoringTypes();
        MonitoringType GetMonitoringTypeById(int id);
        void CreateMonitoringType(Post.MonitoringType monitoringType);
        void UpdateMonitoringType(MonitoringType monitoringType);
        void DeleteMonitoringType(int id);
        void CreateDefaultMonitoringTypes();
    }
}
