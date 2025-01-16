using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Services.Interfaces
{
    public interface IScalingFactorService
    {
        IEnumerable<ScalingFactor> GetAllScalingFactors();
        ScalingFactor GetScalingFactorById(int id);
        void CreateScalingFactor(Post.ScalingFactor scalingFactor);
        void UpdateScalingFactor(ScalingFactor scalingFactor);
        void DeleteScalingFactor(int id);
    }
}
