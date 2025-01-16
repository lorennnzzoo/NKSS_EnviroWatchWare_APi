using Models;
using Post = Models.Post;
using System.Collections.Generic;
namespace Repositories.Interfaces
{
    public interface IMonitoringTypeRepository
    {
        MonitoringType GetById(int id);
        IEnumerable<MonitoringType> GetAll();
        void Add(Post.MonitoringType monitoringType);
        void Update(MonitoringType monitoringType);
        void Delete(int id);
    }
}
